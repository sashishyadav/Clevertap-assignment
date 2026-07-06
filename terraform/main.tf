# ---------------------------------------------------------------------------
# Root module — composes the environment from reusable modules.
#   network -> loadbalancing + data -> compute + cdn
# ---------------------------------------------------------------------------
locals {
  name = "${var.project_name}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  name                       = local.name
  vpc_cidr                   = var.vpc_cidr
  az_count                   = var.az_count
  single_nat_gateway         = var.single_nat_gateway
  container_port             = var.container_port
  restrict_alb_to_cloudfront = var.restrict_alb_to_cloudfront
}

module "data" {
  source = "./modules/data"

  name               = local.name
  private_subnet_ids = module.network.private_subnet_ids
  rds_sg_id          = module.network.rds_sg_id
  redis_sg_id        = module.network.redis_sg_id

  db_engine_version    = var.db_engine_version
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_name              = var.db_name
  db_username          = var.db_username
  db_multi_az          = var.db_multi_az

  cache_node_type    = var.cache_node_type
  cache_num_replicas = var.cache_num_replicas
}

module "loadbalancing" {
  source = "./modules/loadbalancing"

  name                = local.name
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  alb_sg_id           = module.network.alb_sg_id
  container_port      = var.container_port
  acm_certificate_arn = var.acm_certificate_arn
}

module "compute" {
  source = "./modules/compute"

  name                    = local.name
  region                  = var.region
  private_subnet_ids      = module.network.private_subnet_ids
  ecs_sg_id               = module.network.ecs_sg_id
  target_group_arn        = module.loadbalancing.target_group_arn
  alb_arn_suffix          = module.loadbalancing.alb_arn_suffix
  target_group_arn_suffix = module.loadbalancing.target_group_arn_suffix

  db_secret_arn  = module.data.db_secret_arn
  rds_address    = module.data.rds_address
  redis_endpoint = module.data.redis_primary_endpoint
  db_name        = var.db_name

  container_image        = var.container_image
  container_port         = var.container_port
  task_cpu               = var.task_cpu
  task_memory            = var.task_memory
  service_desired_count  = var.service_desired_count
  service_min_capacity   = var.service_min_capacity
  service_max_capacity   = var.service_max_capacity
  off_hours_min_capacity = var.off_hours_min_capacity

  # Ensure the ALB listener exists before the service registers targets.
  depends_on = [module.loadbalancing]
}

module "cdn" {
  source = "./modules/cdn"

  name                = local.name
  alb_dns_name        = module.loadbalancing.alb_dns_name
  acm_certificate_arn = var.acm_certificate_arn
}
