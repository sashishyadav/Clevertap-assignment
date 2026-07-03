# ---------------------------------------------------------------------------
# Security groups — layered, least-privilege network segmentation.
# Internet -> ALB -> ECS tasks -> (RDS, Redis)
# Each tier only accepts traffic from the tier directly in front of it.
# ---------------------------------------------------------------------------

# AWS-managed prefix list of CloudFront's origin-facing IP ranges.
# Locking the ALB to this means users cannot bypass the CDN/WAF and hit the
# ALB directly — all public traffic must flow through CloudFront.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# ALB: ingress on 80/443 only from CloudFront (or the whole internet if the
# restriction is disabled for a quick direct-to-ALB demo).
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB ingress on HTTP/HTTPS from CloudFront only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP from CloudFront"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = var.restrict_alb_to_cloudfront ? null : ["0.0.0.0/0"]
    prefix_list_ids = var.restrict_alb_to_cloudfront ? [data.aws_ec2_managed_prefix_list.cloudfront.id] : null
  }

  ingress {
    description     = "HTTPS from CloudFront"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = var.restrict_alb_to_cloudfront ? null : ["0.0.0.0/0"]
    prefix_list_ids = var.restrict_alb_to_cloudfront ? [data.aws_ec2_managed_prefix_list.cloudfront.id] : null
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

# ECS tasks: ingress only from the ALB SG
resource "aws_security_group" "ecs" {
  name        = "${local.name}-ecs-sg"
  description = "ECS tasks ingress from ALB only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "App port from ALB"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound (image pull, RDS, Redis, AWS APIs)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ecs-sg" }
}

# RDS: ingress only from ECS tasks on the Postgres port
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS ingress from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = { Name = "${local.name}-rds-sg" }
}

# ElastiCache: ingress only from ECS tasks on the Redis port
resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "ElastiCache ingress from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = { Name = "${local.name}-redis-sg" }
}
