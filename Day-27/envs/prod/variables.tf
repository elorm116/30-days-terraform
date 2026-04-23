variable "app_name" {
  description = "Application name — prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

# Primary region
variable "primary_ami_id" { type = string }
variable "primary_vpc_cidr" { type = string }
variable "primary_public_subnet_cidrs" { type = list(string) }
variable "primary_private_subnet_cidrs" { type = list(string) }
variable "primary_availability_zones" { type = list(string) }

# Secondary region
variable "secondary_ami_id" { type = string }
variable "secondary_vpc_cidr" { type = string }
variable "secondary_public_subnet_cidrs" { type = list(string) }
variable "secondary_private_subnet_cidrs" { type = list(string) }
variable "secondary_availability_zones" { type = list(string) }

# EC2
variable "instance_type" { 
  type = string
  default = "t3.micro" 
  }
variable "min_size" { 
  type = number
  default = 1 
  }
variable "max_size" { 
  type = number
  default = 4 
  }
variable "desired_capacity" { 
  type = number
  default = 2 
  }

# RDS
variable "db_name" { type = string }
variable "db_username" { 
  type = string 
  sensitive = true 
  }
variable "db_instance_class" { 
  type = string 
  default = "db.t3.micro" 
  }
variable "db_allocated_storage" { 
  type = number
  default = 20 
  }


# Route53
variable "hosted_zone_id" { type = string }
variable "domain_name" { type = string }

