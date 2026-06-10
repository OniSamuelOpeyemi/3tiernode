output "cloudfront_web_domain" {
  description = "CloudFront distribution URL for the web tier"
  value       = module.cdn.web_distribution_domain
}

output "cloudfront_api_domain" {
  description = "CloudFront distribution URL for the API tier"
  value       = module.cdn.api_distribution_domain
}

output "web_alb_dns" {
  description = "Web ALB DNS (use CloudFront in production)"
  value       = module.ecs.web_alb_dns_name
}

output "api_alb_dns" {
  description = "API ALB DNS (use CloudFront in production)"
  value       = module.ecs.api_alb_dns_name
}

output "ecr_web_repo" {
  description = "ECR repo URL for the web service"
  value       = module.ecr.web_repo_url
}

output "ecr_api_repo" {
  description = "ECR repo URL for the API service"
  value       = module.ecr.api_repo_url
}

output "db_endpoint" {
  description = "Aurora cluster writer endpoint"
  value       = module.database.cluster_endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}


output "db_name" {
  value = var.db_name
}
