# dev.tfvars — Development environment
# Used with: terraform workspace select dev && terraform plan -var-file=dev.tfvars

cluster_name             = "mali-webserver"
aws_region               = "us-east-1"
instance_type            = "t3.micro"
server_port              = 8080
min_size                 = 2
max_size                 = 4
desired_capacity         = 2
cpu_alarm_threshold_high = 80
cpu_alarm_threshold_low  = 10
alert_emails             = ["anthonyzottor@gmail.com"]
