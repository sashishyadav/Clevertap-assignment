# ---------------------------------------------------------------------------
# Application Auto Scaling for the ECS service.
#  - Target tracking on CPU AND ALB request-count-per-target (reacts to a
#    traffic spike faster than CPU alone).
#  - Scheduled actions raise the floor during business hours and drop it
#    off-hours for cost savings.
# ---------------------------------------------------------------------------
resource "aws_appautoscaling_target" "ecs" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.service_min_capacity
  max_capacity       = var.service_max_capacity
}

# --- Target tracking: CPU utilization ---------------------------------------
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name}-cpu-tracking"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# --- Target tracking: ALB requests per target (spike-sensitive) -------------
resource "aws_appautoscaling_policy" "requests" {
  name               = "${local.name}-alb-request-tracking"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.this.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value       = 1000 # requests per task per minute
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# --- Scheduled scaling: business hours vs off-hours (cost saving) -----------
# Times are UTC. Adjust to your primary user timezone.
resource "aws_appautoscaling_scheduled_action" "business_hours" {
  name               = "${local.name}-scale-up-business-hours"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  # 08:00 UTC Mon-Fri
  schedule = "cron(0 8 ? * MON-FRI *)"

  scalable_target_action {
    min_capacity = var.service_min_capacity
    max_capacity = var.service_max_capacity
  }
}

resource "aws_appautoscaling_scheduled_action" "off_hours" {
  name               = "${local.name}-scale-down-off-hours"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  # 20:00 UTC daily
  schedule = "cron(0 20 * * ? *)"

  scalable_target_action {
    min_capacity = var.off_hours_min_capacity
    max_capacity = var.service_max_capacity
  }
}
