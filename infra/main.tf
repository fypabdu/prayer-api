terraform {
  backend "remote" {
    organization = "abu"

    workspaces {
      name = "prayer-api"
    }
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

# Needed for ALB log bucket naming & policy
data "aws_caller_identity" "current" {}

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

data "aws_ami" "ubuntu" {
  owners = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  most_recent = true
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/prayer-api/app"
  retention_in_days = 30
}

resource "aws_launch_template" "prayer_api" {
  name_prefix   = "prayer-api-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # Add IAM instance profile for SSM + CloudWatch Agent
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_profile.name
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail

    # --- base packages & docker ---
    apt-get update -y
    apt-get install -y docker.io curl

    systemctl enable docker
    systemctl start docker

    # --- Amazon SSM Agent (Ubuntu 20.04) ---
    if ! systemctl is-active --quiet amazon-ssm-agent; then
      curl -fsSL -o /tmp/amazon-ssm-agent.deb https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
      dpkg -i /tmp/amazon-ssm-agent.deb || apt-get -f install -y
      systemctl enable amazon-ssm-agent
      systemctl restart amazon-ssm-agent
    fi

    # --- CloudWatch Agent (Ubuntu .deb) ---
    curl -fsSL -o /tmp/amazon-cloudwatch-agent.deb https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i /tmp/amazon-cloudwatch-agent.deb || apt-get -f install -y

    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CFG
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
        },
        "force_flush_interval": 5
      }
    }
    CFG

    systemctl enable amazon-cloudwatch-agent
    systemctl restart amazon-cloudwatch-agent

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

  depends_on = [aws_lb_listener.prayer_api]
}

# -----------------------------
# Load Balancer (+ Access Logs)
# -----------------------------

# S3 bucket for ALB access logs (no ACLs; bucket policy used)
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

# Enforce Bucket Owner; ACLs are disabled (fixes previous ACL error)
resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 90-day lifecycle for logs
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  rule {
    id     = "expire-90-days"
    status = "Enabled"
    expiration { days = 90 }
    filter {}
  }
}

# Bucket policy that allows ALB log delivery to write/list
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite",
        Effect = "Allow",
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        },
        Action   = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn" = aws_lb.prayer_api.arn
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryCheck",
        Effect = "Allow",
        Principal = {
          Service = "logdelivery.elasticloadbalancing.amazonaws.com"
        },
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = aws_s3_bucket.alb_logs.arn,
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          ArnLike = {
            "aws:SourceArn" = aws_lb.prayer_api.arn
          }
        }
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

# Core SSM access
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# For CloudWatch Logs shipping (agent)
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "prayer-api-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}
