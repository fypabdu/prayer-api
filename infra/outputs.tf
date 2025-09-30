output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.prayer_api.dns_name
}

output "deployed_image" {
  description = "Deployed Docker image"
  value       = "${var.ecr_repo_url}:${var.image_tag}"
}
