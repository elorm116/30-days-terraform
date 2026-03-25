# This is the production calling configuration.
# Same module, completely different inputs.
# Larger instances, higher min/max capacity.
# Zero code duplication with dev.

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-production"
  instance_type = "t3.small"
  min_size      = 4
  max_size      = 10
}

output "alb_dns_name" {
  description = "Production cluster URL"
  value       = module.webserver_cluster.alb_dns_name
}