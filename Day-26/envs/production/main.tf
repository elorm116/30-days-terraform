# envs/production/main.tf
# Root module for production. State is isolated from dev via a different backend key.

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Step 1: ALB
module "alb" {
  source      = "../../modules/alb"
  name        = var.app_name
  vpc_id      = data.aws_vpc.selected.id
  subnet_ids  = var.public_subnet_ids
  environment = var.environment

  health_check_path            = "/health"
  enable_deletion_protection   = true
  high_request_count_threshold = var.high_request_count_threshold

  tags = local.shared_tags
}

# Step 2: Launch template + instance SG
module "ec2" {
  source                = "../../modules/ec2"
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  environment           = var.environment
  app_name              = var.app_name
  vpc_id                = data.aws_vpc.selected.id
  alb_security_group_id = module.alb.alb_security_group_id
  key_name              = var.key_name

  tags = local.shared_tags
}

# Step 3: ASG (private subnets)
module "asg" {
  source                  = "../../modules/asg"
  launch_template_id      = module.ec2.launch_template_id
  launch_template_version = module.ec2.launch_template_version
  subnet_ids              = var.private_subnet_ids
  target_group_arns       = [module.alb.target_group_arn]

  min_size                = var.min_size
  max_size                = var.max_size
  desired_capacity        = var.desired_capacity
  cpu_scale_out_threshold = var.cpu_scale_out_threshold
  cpu_scale_in_threshold  = var.cpu_scale_in_threshold

  environment  = var.environment
  app_name      = var.app_name
  force_delete  = false

  tags = local.shared_tags
}

locals {
  shared_tags = {
    Owner      = "terraform-challenge"
    Day        = "26"
    CostCentre = "production-infrastructure"
  }
}
