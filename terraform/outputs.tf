output "cloudfront_domain_name" {
  description = "Public CloudFront domain — the primary entry point for users."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "assets_bucket_name" {
  description = "S3 bucket for static assets (served via CloudFront /static/*)."
  value       = aws_s3_bucket.assets.bucket
}

output "alb_dns_name" {
  description = "ALB DNS name (CloudFront origin — not meant for direct public use)."
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "rds_endpoint" {
  description = "RDS connection endpoint (private)."
  value       = aws_db_instance.this.address
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis primary endpoint (private)."
  value       = aws_elasticache_replication_group.this.primary_endpoint_address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding DB credentials."
  value       = aws_secretsmanager_secret.db.arn
}

output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN associated with the ALB."
  value       = aws_wafv2_web_acl.this.arn
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}
