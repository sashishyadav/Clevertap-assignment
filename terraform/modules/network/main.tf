# ---------------------------------------------------------------------------
# Network module: VPC, subnets across AZs, NAT, routing, flow logs, and the
# layered security groups (internet -> ALB -> ECS -> RDS/Redis).
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs                  = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  nat_gateway_count    = var.single_nat_gateway ? 1 : var.az_count
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.name}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-igw" }
}

resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  }
}

resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  }
}

# --- NAT gateways -----------------------------------------------------------
resource "aws_eip" "nat" {
  count      = local.nat_gateway_count
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags       = { Name = "${var.name}-nat-eip-${count.index}" }
}

resource "aws_nat_gateway" "this" {
  count         = local.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "${var.name}-nat-${count.index}" }
}

# --- Route tables -----------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = var.az_count
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }
  tags = { Name = "${var.name}-private-rt-${local.azs[count.index]}" }
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# --- VPC Flow Logs (auditability) -------------------------------------------
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = 30
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name}-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id
  tags            = { Name = "${var.name}-flow-log" }
}

# ---------------------------------------------------------------------------
# Security groups — least-privilege, tier-to-tier only.
# ---------------------------------------------------------------------------
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
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

  tags = { Name = "${var.name}-alb-sg" }
}

resource "aws_security_group" "ecs" {
  name        = "${var.name}-ecs-sg"
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

  tags = { Name = "${var.name}-ecs-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS ingress from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = { Name = "${var.name}-rds-sg" }
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "ElastiCache ingress from ECS tasks only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }

  tags = { Name = "${var.name}-redis-sg" }
}
