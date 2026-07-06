output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "rds_address" {
  value = aws_db_instance.this.address
}

output "redis_primary_endpoint" {
  value = aws_elasticache_replication_group.this.primary_endpoint_address
}
