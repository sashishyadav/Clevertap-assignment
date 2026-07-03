data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project_name}-${var.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Carve /20 public and /20 private subnets out of the VPC CIDR, one per AZ.
  # Public subnets:  10.0.0.0/20, 10.0.16.0/20, 10.0.32.0/20
  # Private subnets: 10.0.128.0/20, 10.0.144.0/20, 10.0.160.0/20
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
