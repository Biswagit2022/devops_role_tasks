module "vpc" {
  source = "./modules/vpc"

  devops_practice         = var.devops_practice
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "security" {
  source = "./modules/security"

  devops_practice   = var.devops_practice
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  container_port = var.container_port
  admin_ip_cidr  = var.admin_ip_cidr
}

module "rds" {
  source = "./modules/rds"

  devops_practice         = var.devops_practice
  environment          = var.environment
  private_subnet_ids   = module.vpc.private_subnet_ids
  security_group_id    = module.security.rds_sg_id
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine_version    = var.db_engine_version
}

module "alb" {
  source = "./modules/alb"

  devops_practice      = var.devops_practice
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_sg_id
  container_port    = var.container_port
}

module "ecs" {
  source = "./modules/ecs"

  devops_practice       = var.devops_practice
  environment        = var.environment
  aws_region         = var.aws_region
  private_subnet_ids = module.vpc.private_subnet_ids
  security_group_id  = module.security.ecs_sg_id
  target_group_arn   = module.alb.target_group_arn
  alb_listener_arn   = module.alb.listener_arn

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory
  desired_count   = var.desired_count

  db_endpoint = module.rds.db_endpoint
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}