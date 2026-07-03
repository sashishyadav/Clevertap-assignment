variable "project_name" {
  description = "Project name used for tagging and resource naming."
  type        = string
  default     = "engagement-platform"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "region" {
  description = "AWS region for the primary deployment."
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread across (>=2 for HA, 3 recommended)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving) instead of one per AZ (HA). Set false for prod-grade HA."
  type        = bool
  default     = true
}

variable "restrict_alb_to_cloudfront" {
  description = "Lock ALB ingress to CloudFront's managed prefix list so the CDN/WAF can't be bypassed. Set false only for direct-to-ALB debugging."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Application / ECS
# ---------------------------------------------------------------------------
variable "container_image" {
  description = "Container image for the application service."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:stable"
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 1024
}

variable "service_desired_count" {
  description = "Baseline desired task count."
  type        = number
  default     = 2
}

variable "service_min_capacity" {
  description = "Minimum tasks (autoscaling floor during business hours)."
  type        = number
  default     = 2
}

variable "service_max_capacity" {
  description = "Maximum tasks (autoscaling ceiling during campaign spikes)."
  type        = number
  default     = 20
}

variable "off_hours_min_capacity" {
  description = "Scheduled scale-down floor for off-hours cost savings."
  type        = number
  default     = 1
}

# ---------------------------------------------------------------------------
# ACM / TLS
# ---------------------------------------------------------------------------
variable "acm_certificate_arn" {
  description = "ACM certificate ARN for the HTTPS listener. If empty, only HTTP is exposed (demo only)."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# RDS
# ---------------------------------------------------------------------------
variable "db_engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "16.4"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "engagement"
}

variable "db_username" {
  description = "Master DB username."
  type        = string
  default     = "app_admin"
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ for high availability."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# ElastiCache (Redis / Valkey-compatible)
# ---------------------------------------------------------------------------
variable "cache_node_type" {
  description = "ElastiCache node type."
  type        = string
  default     = "cache.t4g.small"
}

variable "cache_num_replicas" {
  description = "Number of read replicas per shard (>=1 enables Multi-AZ failover)."
  type        = number
  default     = 1
}
