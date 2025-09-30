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

# -----------------------------
# Networking (VPC, Subnets, SG)
# -----------------------------

resource "aws_vpc" "prayer_api" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "prayer-api-vpc"
  }
}

resource "aws_internet_gateway" "prayer_api" {
  vpc_id = aws_vpc.prayer_api.id
  tags = {
    Name = "prayer-api-igw"
  }
}

resource "aws_subnet" "prayer_api_a" {
  vpc_id                  = aws_vpc.prayer_api.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "prayer-api-subnet-a"
  }
}

resource "aws_subnet" "prayer_api_b" {
  vpc_id                  = aws_vpc.prayer_api.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "prayer-api-subnet-b"
  }
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

  tags = {
    Name = "prayer-api-sg"
  }
}

# -----------------------------
# Compute (Launch Template, ASG)
# -----------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-*"]
  }
}

resource "aws_launch_template" "prayer_api" {
  name_prefix   = "prayer-api-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t4g.nano"

  user_data = base64encode(<<EOT
#!/bin/bash
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
docker run -d -p 80:8000 ${var.ecr_repo_url}:${var.image_tag}
EOT
  )

  vpc_security_group_ids = [aws_security_group.prayer_api.id]

  lifecycle {
    create_before_destroy = true
  }
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
  target_group_arns   = [aws_lb_target_group.prayer_api.arn]

  tag {
    key                 = "Name"
    value               = "prayer-api"
    propagate_at_launch = true
  }

  depends_on = [aws_lb_listener.prayer_api]
}

# -----------------------------
# Load Balancer
# -----------------------------

resource "aws_lb" "prayer_api" {
  name               = "prayer-api-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prayer_api.id]
  subnets            = [aws_subnet.prayer_api_a.id, aws_subnet.prayer_api_b.id]
}

resource "aws_lb_target_group" "prayer_api" {
  name     = "prayer-api-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prayer_api.id

  health_check {
    path                = "/"
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
