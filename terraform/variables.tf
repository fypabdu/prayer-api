variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
}
