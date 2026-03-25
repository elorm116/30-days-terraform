# This is the dev calling configuration.
# It calls the webserver-cluster module and passes dev-appropriate values.
# Notice there are no resource definitions here — just a module call.
# All the infrastructure logic lives inside the module.

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

# Surface the ALB DNS name after apply so you can test immediately
output "alb_dns_name" {
  description = "Dev cluster URL"
  value       = module.webserver_cluster.alb_dns_name
}