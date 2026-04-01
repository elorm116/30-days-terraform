# This is the dev calling configuration.
# It calls the webserver-cluster module and passes dev-appropriate values.
# Notice there are no resource definitions here — just a module call.
# All the infrastructure logic lives inside the module.

module "webserver_cluster" {
  source = "github.com/elorm116/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
  custom_message = "Dev — Testing Latest Module Version"

}

# Surface the ALB DNS name after apply so you can test immediately
output "alb_dns_name" {
  description = "Dev cluster URL"
  value       = module.webserver_cluster.alb_dns_name
}