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
      image_identifier      = "${aws_ecrpublic_repository.prayer_api.repository_uri}:${var.image_tag}"
      image_repository_type = "ECR_PUBLIC"
    }
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

resource "aws_ecrpublic_repository" "prayer_api" {
  repository_name = "prayer-api"

  catalog_data {
    about_text  = "Prayer API Docker image"
    description = "Public ECR repo for Prayer API"
  }
}

output "ecr_repo_url" {
  value = aws_ecrpublic_repository.prayer_api.repository_uri
}


output "apprunner_url" {
  description = "Default App Runner service URL"
  value       = aws_apprunner_service.this.service_url
}
