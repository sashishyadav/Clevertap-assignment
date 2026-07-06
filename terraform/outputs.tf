output "cloudfront_domain_name" {
  description = "Public CloudFront domain — the primary entry point for users."
  value       = module.cdn.cloudfront_domain_name
}

output "assets_bucket_name" {
  description = "S3 bucket for static assets (served via CloudFront /static/*)."
  value       = module.cdn.bucket_name
}

output "alb_dns_name" {
  description = "ALB DNS name (CloudFront origin — not meant for direct public use)."
  value       = module.loadbalancing.alb_dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.compute.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = module.compute.service_name
}

output "rds_endpoint" {
  description = "RDS connection endpoint (private)."
  value       = module.data.rds_address
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint (private)."
  value       = module.data.redis_primary_endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials."
  value       = module.data.db_secret_arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN associated with the ALB."
  value       = module.loadbalancing.waf_web_acl_arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}
