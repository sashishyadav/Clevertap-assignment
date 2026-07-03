# ---------------------------------------------------------------------------
# ECS on Fargate — serverless containers, no EC2 to manage.
# Capacity provider strategy mixes FARGATE (baseline, stable) with
# FARGATE_SPOT (burst, ~70% cheaper) for the cost-optimization requirement.
# ---------------------------------------------------------------------------
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  # Baseline of 1 task on stable FARGATE; everything above scales on SPOT.
  # weight 1:3 => ~25% on-demand / ~75% spot above the base.
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    base              = 1
    weight            = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 3
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}/app"
  retention_in_days = 30
}

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64" # Graviton — cheaper per vCPU
  }

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.container_image
      essential = true

      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.this.primary_endpoint_address },
        { name = "REDIS_PORT", value = "6379" },
        { name = "DB_HOST", value = aws_db_instance.this.address },
        { name = "DB_PORT", value = "5432" },
        { name = "DB_NAME", value = var.db_name }
      ]

      # Password injected from Secrets Manager, never baked into the image.
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.db.arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = { Name = "${local.name}-app" }
}

resource "aws_ecs_service" "app" {
  name            = "${local.name}-app"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.service_desired_count

  # Use the cluster default capacity provider strategy (FARGATE + SPOT).
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Ignore desired_count so autoscaling / scheduled actions own it.
  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy.task_execution_secrets,
  ]

  tags = { Name = "${local.name}-app" }
}
