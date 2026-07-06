variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "container_port" {
  description = "Target group / container port."
  type        = number
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Empty = HTTP only (demo)."
  type        = string
}
