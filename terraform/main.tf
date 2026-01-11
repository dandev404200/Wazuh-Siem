# Wazuh SIEM POC Infrastructure
# Orchestrated with OpenTofu

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix         = local.name_prefix
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  availability_zone   = var.availability_zone
}

# Security Groups Module
module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
}

# IAM Module (SSM access)
module "iam" {
  source = "./modules/iam"

  name_prefix = local.name_prefix
}

# NLB Module
module "nlb" {
  source = "./modules/nlb"

  name_prefix       = local.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_id
}

# Compute Module (EC2)
module "compute" {
  source = "./modules/compute"

  name_prefix            = local.name_prefix
  instance_type          = var.instance_type
  volume_size            = var.volume_size
  private_subnet_id      = module.vpc.private_subnet_id
  security_group_id      = module.security.ec2_security_group_id
  iam_instance_profile   = module.iam.instance_profile_name
  wazuh_version          = var.wazuh_version
  nlb_target_group_arns  = module.nlb.target_group_arns
}

# Register EC2 with NLB target groups
resource "aws_lb_target_group_attachment" "dashboard" {
  target_group_arn = module.nlb.dashboard_target_group_arn
  target_id        = module.compute.instance_id
  port             = 443
}

resource "aws_lb_target_group_attachment" "agent_events" {
  target_group_arn = module.nlb.agent_events_target_group_arn
  target_id        = module.compute.instance_id
  port             = 1514
}

resource "aws_lb_target_group_attachment" "agent_registration" {
  target_group_arn = module.nlb.agent_registration_target_group_arn
  target_id        = module.compute.instance_id
  port             = 1515
}
