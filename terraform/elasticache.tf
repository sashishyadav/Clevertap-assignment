# ---------------------------------------------------------------------------
# ElastiCache Redis (Valkey-compatible) — cache-aside layer in front of RDS.
# Multi-AZ with automatic failover, encryption in transit + at rest.
# Shields the database during campaign read spikes.
# ---------------------------------------------------------------------------
resource "aws_elasticache_subnet_group" "this" {
  name       = "${local.name}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${local.name}-redis"
  description          = "Cache-aside layer for ${local.name}"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.cache_node_type
  port           = 6379

  # 1 primary + N replicas, spread across AZs.
  num_cache_clusters         = var.cache_num_replicas + 1
  automatic_failover_enabled = var.cache_num_replicas >= 1
  multi_az_enabled           = var.cache_num_replicas >= 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 5
  apply_immediately        = true

  tags = { Name = "${local.name}-redis" }
}
