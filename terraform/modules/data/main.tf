# ---------------------------------------------------------------------------
# Data module: RDS PostgreSQL (Multi-AZ), ElastiCache Redis (cache-aside),
# and generated DB credentials in Secrets Manager.
# ---------------------------------------------------------------------------

# --- Credentials ------------------------------------------------------------
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/db/credentials"
  description = "Master credentials for ${var.name} RDS"
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = 5432
    dbname   = var.db_name
  })
}

# --- RDS --------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${var.name}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  port                   = 5432

  backup_retention_period      = 7
  auto_minor_version_upgrade   = true
  deletion_protection          = false # set true in prod
  skip_final_snapshot          = true  # set false in prod
  performance_insights_enabled = true

  tags = { Name = "${var.name}-db" }
}

# --- ElastiCache Redis ------------------------------------------------------
resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-cache-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.name}-redis"
  description          = "Cache-aside layer for ${var.name}"

  engine         = "redis"
  engine_version = "7.1"
  node_type      = var.cache_node_type
  port           = 6379

  num_cache_clusters         = var.cache_num_replicas + 1
  automatic_failover_enabled = var.cache_num_replicas >= 1
  multi_az_enabled           = var.cache_num_replicas >= 1

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.redis_sg_id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  snapshot_retention_limit = 5
  apply_immediately        = true

  tags = { Name = "${var.name}-redis" }
}
