variable "name" {
  description = "Name prefix for resources."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS and ElastiCache."
  type        = list(string)
}

variable "rds_sg_id" {
  description = "Security group ID for RDS."
  type        = string
}

variable "redis_sg_id" {
  description = "Security group ID for ElastiCache."
  type        = string
}

# --- RDS --------------------------------------------------------------------
variable "db_engine_version" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_multi_az" {
  type = bool
}

# --- ElastiCache ------------------------------------------------------------
variable "cache_node_type" {
  type = string
}

variable "cache_num_replicas" {
  type = number
}
