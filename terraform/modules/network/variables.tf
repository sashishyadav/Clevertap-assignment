variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "az_count" {
  description = "Number of Availability Zones to spread across."
  type        = number
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving) instead of one per AZ (HA)."
  type        = bool
}

variable "container_port" {
  description = "Application container port (for the ECS security group ingress)."
  type        = number
}

variable "restrict_alb_to_cloudfront" {
  description = "Lock ALB ingress to CloudFront's managed prefix list."
  type        = bool
}
