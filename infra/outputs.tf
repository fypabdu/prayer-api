output "service_url" {
  value = aws_apprunner_service.this.service_url
}

output "ecr_url" {
  value = aws_ecrpublic_repository.prayer_api.repository_uri
}

output "apprunner_service_url" {
  description = "The default domain URL of the App Runner service"
  value       = aws_apprunner_service.this.service_url
}

output "apprunner_service_arn" {
  description = "ARN of the App Runner service"
  value       = aws_apprunner_service.this.arn
}

output "deployed_image" {
  description = "The Docker image deployed by App Runner"
  value       = "${aws_ecrpublic_repository.prayer_api.repository_uri}:${var.image_tag}"
}
