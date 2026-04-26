output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "dynatrace_api_token_secret_arn" {
  description = "ARN of Dynatrace API token secret"
  value       = aws_secretsmanager_secret.dynatrace_api_token.arn
}

output "dynatrace_environment_id_secret_arn" {
  description = "ARN of Dynatrace environment ID secret"
  value       = aws_secretsmanager_secret.dynatrace_environment_id.arn
}
