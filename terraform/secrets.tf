# ---------------------------------------------------------------------------
# DB credentials — generated, never hard-coded, stored in Secrets Manager.
# ECS injects the password into the container from here at task start.
# ---------------------------------------------------------------------------
resource "random_password" "db" {
  length  = 24
  special = true
  # RDS disallows a few characters in the master password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name        = "${local.name}/db/credentials"
  description = "Master credentials for ${local.name} RDS"
  # Use the default AWS-managed KMS key for Secrets Manager.
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
