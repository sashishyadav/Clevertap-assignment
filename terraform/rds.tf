# ---------------------------------------------------------------------------
# RDS PostgreSQL — Multi-AZ for HA, encrypted at rest, private subnets only.
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${local.name}-db-subnet-group" }
}

resource "aws_db_instance" "this" {
  identifier     = "${local.name}-db"
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 5 # storage autoscaling
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result

  multi_az               = var.db_multi_az
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  port                   = 5432

  backup_retention_period      = 7
  auto_minor_version_upgrade   = true
  deletion_protection          = false # set true in prod
  skip_final_snapshot          = true  # set false in prod
  performance_insights_enabled = true

  tags = { Name = "${local.name}-db" }
}
