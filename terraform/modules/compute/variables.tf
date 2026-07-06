variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "region" {
  description = "AWS region (for CloudWatch Logs config)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks."
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "Security group ID for ECS tasks."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to register tasks with."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (for the request-count autoscaling metric)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix (for the request-count autoscaling metric)."
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for DB credentials."
  type        = string
}

variable "rds_address" {
  description = "RDS endpoint address."
  type        = string
}

variable "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint."
  type        = string
}

variable "db_name" {
  type = string
}

variable "container_image" {
  type = string
}

variable "container_port" {
  type = number
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "service_desired_count" {
  type = number
}

variable "service_min_capacity" {
  type = number
}

variable "service_max_capacity" {
  type = number
}

variable "off_hours_min_capacity" {
  type = number
}
