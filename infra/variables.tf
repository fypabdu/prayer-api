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

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS Access Key"
  type        = string
  default     = ""
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS Secret Key"
  type        = string
  default     = ""
}

variable "AWS_DEFAULT_REGION" {
  description = "AWS Default region"
  type        = string
  default     = "us-east-1"
}
