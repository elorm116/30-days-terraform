# prod.tfvars — Production environment
# Used with: terraform workspace select prod && terraform plan -var-file=prod.tfvars
# IMPORTANT: Any plan showing resource destructions requires secondary approval before apply

cluster_name             = "mali-webserver"
aws_region               = "us-east-1"
instance_type            = "t3.small"
server_port              = 8080
min_size                 = 3
max_size                 = 10
desired_capacity         = 3
cpu_alarm_threshold_high = 75
alert_emails             = ["anthonyzottor@gmail.com"]
