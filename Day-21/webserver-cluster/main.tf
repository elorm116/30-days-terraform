# Consume the webserver-cluster module from the private registry
module "webserver_cluster" {
  source  = "app.terraform.io/cradx/webserver-cluster/aws"
  version = "0.0.5"

  # Core configuration — REQUIRED
  cluster_name = var.cluster_name
  environment  = var.environment
  project_name = var.project_name

  # Optional — uses module defaults if not specified
  min_size                  = var.min_size
  max_size                  = var.max_size
  instance_type             = var.instance_type
  team_name                 = var.team_name
  server_port               = var.server_port
  alb_port                  = var.alb_port
  custom_message            = var.custom_message
  enable_destroy_protection = var.enable_destroy_protection

  # New monitoring and versioning variables (v0.0.5)
  app_version         = var.app_version
  enable_monitoring   = var.enable_monitoring
  alarm_email         = var.alarm_email
  cpu_alarm_threshold = var.cpu_alarm_threshold
}
