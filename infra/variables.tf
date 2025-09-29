variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repository URL (passed in via environment variable)"
  type        = string
}
