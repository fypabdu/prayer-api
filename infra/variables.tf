variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
}

variable "ecr_repo_url" {
  description = "ECR repository URL for the Docker image"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}
