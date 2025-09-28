terraform {
  required_version = ">= 1.5"
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

resource "aws_apprunner_service" "this" {
  service_name = "prayer-api"

  source_configuration {
    image_repository {
      image_identifier      = "docker.io/abu99/prayer-api:${var.image_tag}"
      image_repository_type = "ECR_PUBLIC"
    }
    auto_deployments_enabled = false
  }

  instance_configuration {
    cpu    = "1024"
    memory = "2048"
  }

  tags = {
    Project = "prayer-api"
    Env     = "production"
  }
}

output "apprunner_url" {
  description = "Default App Runner service URL"
  value       = aws_apprunner_service.this.service_url
}
