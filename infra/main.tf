terraform {
  backend "remote" {
    organization = "abu"
    workspaces { name = "prayer-api" }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Caller/account info for ARNs and bucket names.
data "aws_caller_identity" "current" {}

# Regional ELB log-delivery account (avoids hard-coding).
data "aws_elb_service_account" "this" {}

# -----------------------------
# Networking (VPC, Subnets, SG)
# -----------------------------

resource "aws_vpc" "prayer_api" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "prayer-api-vpc" }
}

resource "aws_internet_gateway" "prayer_api" {
  vpc_id = aws_vpc.prayer_api.id
  tags   = { Name = "prayer-api-igw" }
}

resource "aws_subnet" "prayer_api_a" {
  vpc_id                  = aws_vpc.prayer_api.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "prayer-api-subnet-a" }
}

resource "aws_subnet" "prayer_api_b" {
  vpc_id                  = aws_vpc.prayer_api.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags                    = { Name = "prayer-api-subnet-b" }
}

resource "aws_route_table" "prayer_api" {
  vpc_id = aws_vpc.prayer_api.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prayer_api.id
  }
}

resource "aws_route_table_association" "prayer_api_a" {
  subnet_id      = aws_subnet.prayer_api_a.id
  route_table_id = aws_route_table.prayer_api.id
}

resource "aws_route_table_association" "prayer_api_b" {
  subnet_id      = aws_subnet.prayer_api_b.id
  route_table_id = aws_route_table.prayer_api.id
}

# Security group used by the ALB and EC2 instances.
resource "aws_security_group" "prayer_api" {
  vpc_id = aws_vpc.prayer_api.id
  name   = "prayer-api-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "prayer-api-sg" }
}

# -----------------------------
# Compute (Launch Template, ASG)
# -----------------------------

# Use Amazon Linux 2 so SSM Agent is preinstalled and enabled.
data "aws_ami" "al2" {
  owners      = ["137112412989"] # Amazon
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}


# Log group for application/container logs.
resource "aws_cloudwatch_log_group" "app" {
  name              = "/prayer-api/app"
  retention_in_days = 30
}

resource "aws_launch_template" "prayer_api" {
  name_prefix   = "prayer-api-"
  image_id      = data.aws_ami.al2.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_profile.name
  }

  update_default_version = true

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail

    # Ensure SSM Agent is enabled/running (AL2 has it preinstalled).
    systemctl enable amazon-ssm-agent
    systemctl restart amazon-ssm-agent

    # Docker on Amazon Linux 2
    yum update -y
    amazon-linux-extras enable docker
    yum install -y docker
    systemctl enable docker
    systemctl start docker

    # Install CloudWatch Agent
    yum install -y amazon-cloudwatch-agent

    # Write CloudWatch Agent config for Docker JSON logs
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'CFG'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/lib/docker/containers/*/*-json.log",
                "log_group_name": "/prayer-api/app",
                "log_stream_name": "{instance_id}/docker",
                "timestamp_format": "%Y-%m-%dT%H:%M:%S.%f%z",
                "multi_line_start_pattern": "^{"
              }
            ]
          }
        }
      }
    }
    CFG

    # Start CloudWatch Agent with the config
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

    # Run the application container; host :80 -> container :8000
    docker run -d --restart always -p 80:8000 ${var.ecr_repo_url}:${var.image_tag}
  EOT
  )

  vpc_security_group_ids = [aws_security_group.prayer_api.id]

  lifecycle { create_before_destroy = true }
}

resource "aws_autoscaling_group" "prayer_api" {
  desired_capacity = 1
  min_size         = 1
  max_size         = 3

  launch_template {
    id      = aws_launch_template.prayer_api.id
    version = "$Latest"
  }

  vpc_zone_identifier = [
    aws_subnet.prayer_api_a.id,
    aws_subnet.prayer_api_b.id
  ]

  target_group_arns = [aws_lb_target_group.prayer_api.arn]

  tag {
    key                 = "Name"
    value               = "prayer-api"
    propagate_at_launch = true
  }

  # Roll instances when the LT changes (AMI/user_data/etc).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
    triggers = ["launch_template"]
  }

  depends_on = [aws_lb_listener.prayer_api]
}

# -----------------------------
# Load Balancer and Access Logs
# -----------------------------

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "prayer-api-alb-logs-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  restrict_public_buckets = true
  ignore_public_acls      = true
}

# Use BucketOwnerPreferred to tolerate legacy ACL-based log delivery.
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule { object_ownership = "BucketOwnerPreferred" }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-90-days"
    status = "Enabled"
    expiration { days = 90 }
    filter {}
  }
}

# Bucket policy for ALB log delivery (regional account + service principal).
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowElbRegionalAccountPutObject",
        Effect    = "Allow",
        Principal = { AWS = data.aws_elb_service_account.this.arn },
        Action    = ["s3:PutObject"],
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      },
      {
        Sid       = "AllowAlbServicePutObject",
        Effect    = "Allow",
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" },
        Action    = ["s3:PutObject"],
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id,
            "s3:x-amz-acl"      = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid       = "AllowAlbServiceListGet",
        Effect    = "Allow",
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" },
        Action    = ["s3:ListBucket", "s3:GetBucketLocation"],
        Resource  = aws_s3_bucket.alb_logs.arn,
        Condition = {
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
      {
        Sid       = "AllowElbRegionalAccountListBucket",
        Effect    = "Allow",
        Principal = { AWS = data.aws_elb_service_account.this.arn },
        Action    = ["s3:ListBucket"],
        Resource  = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

resource "aws_lb" "prayer_api" {
  name               = "prayer-api-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prayer_api.id]
  subnets            = [aws_subnet.prayer_api_a.id, aws_subnet.prayer_api_b.id]

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    enabled = true
    prefix  = "alb"
  }
}

resource "aws_lb_target_group" "prayer_api" {
  name     = "prayer-api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prayer_api.id

  health_check {
    path                = "/api/v1/times/today/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "prayer_api" {
  load_balancer_arn = aws_lb.prayer_api.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prayer_api.arn
  }
}

# -----------------------------
# IAM (SSM + CloudWatch Agent)
# -----------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name               = "prayer-api-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Core SSM access for Session Manager & inventory.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Permissions for CloudWatch Agent to publish logs/metrics.
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile EC2 uses at launch.
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "prayer-api-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
