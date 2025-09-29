output "ecr_repo_url" {
  value = var.ecr_repo_url
}

output "deployed_image" {
  value = "${var.ecr_repo_url}:${var.image_tag}"
}

output "apprunner_url" {
  description = "Default App Runner service URL"
  value       = aws_apprunner_service.this.service_url
}
