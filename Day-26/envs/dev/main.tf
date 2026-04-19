# envs/dev/main.tf
#
# Root module for the dev environment.
# This file is intentionally thin — all logic lives in the three child modules.
# The calling configuration's job is to wire module outputs to module inputs.
#
# Data flow:
#   module.alb → module.ec2 (alb_security_group_id)
#   module.ec2 → module.asg (launch_template_id, launch_template_version)
#   module.alb → module.asg (target_group_arn)

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id]
  }
}

data "aws_subnet" "discovered" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

# ── Step 1: ALB Module ─────────────────────────────────────────────────────────
# The ALB module is called first because it creates the security group
# whose ID is needed by the EC2 module. The ALB SG is what the EC2
# instance security group allows as an inbound source.
module "alb" {
  source      = "../../modules/alb"
  name        = var.app_name
  vpc_id      = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
  subnet_ids  = local.effective_public_subnet_ids
  environment = var.environment

  health_check_path            = "/health"
  enable_deletion_protection   = false  # dev only — allow terraform destroy
  high_request_count_threshold = var.high_request_count_threshold

  tags = local.shared_tags
}

# ── Step 2: EC2 Module ─────────────────────────────────────────────────────────
# The EC2 module receives the ALB security group ID from Step 1.
# This creates the security rule: instances ← ALB SG only.
# Without this, instances would need to accept traffic from 0.0.0.0/0 directly,
# which would defeat the purpose of the ALB security boundary.
module "ec2" {
  source                = "../../modules/ec2"
  ami_id                = var.ami_id
  instance_type         = var.instance_type
  environment           = var.environment
  app_name              = var.app_name
  vpc_id                = var.vpc_id != "" ? var.vpc_id : data.aws_vpc.default.id
  alb_security_group_id = module.alb.alb_security_group_id  # ← wired from ALB output
  key_name              = var.key_name

  tags = local.shared_tags
}

# ── Step 3: ASG Module ─────────────────────────────────────────────────────────
# The ASG module receives:
#   - launch_template_id      from the EC2 module (what to launch)
#   - launch_template_version from the EC2 module (which version to use)
#   - target_group_arns       from the ALB module (where to register instances)
#
# These three inputs close the full circuit:
#   EC2 module defines WHAT runs → ASG module orchestrates HOW MANY run
#   ALB module defines HOW TRAFFIC REACHES them → target_group_arns connects all three
module "asg" {
  source                   = "../../modules/asg"
  launch_template_id       = module.ec2.launch_template_id       # ← from EC2 module
  launch_template_version  = module.ec2.launch_template_version  # ← from EC2 module
  subnet_ids               = local.effective_public_subnet_ids
  target_group_arns        = [module.alb.target_group_arn]       # ← from ALB module
  min_size                 = var.min_size
  max_size                 = var.max_size
  desired_capacity         = var.desired_capacity
  cpu_scale_out_threshold  = var.cpu_scale_out_threshold
  cpu_scale_in_threshold   = var.cpu_scale_in_threshold
  environment              = var.environment
  app_name                 = var.app_name
  force_delete             = true  # safe in dev — allows clean terraform destroy

  tags = local.shared_tags
}

locals {
  discovered_public_subnet_ids = [
    for s in values(data.aws_subnet.discovered) : s.id
    if !contains(var.excluded_availability_zones, s.availability_zone)
  ]

  effective_public_subnet_ids = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : local.discovered_public_subnet_ids

  shared_tags = {
    Owner      = "terraform-challenge"
    Day        = "26"
    CostCentre = "dev-infrastructure"
  }
}
