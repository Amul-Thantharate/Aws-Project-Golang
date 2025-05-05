output "alb_url" {
  value = "http://${aws_lb.app.dns_name}"
}

output "ecr_repo" {
  value = aws_ecr_repository.app.repository_url
}

