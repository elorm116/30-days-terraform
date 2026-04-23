variable "identifier" {
  description = "Unique identifier for the RDS instance. Must be unique per region per account."
  type        = string
}

variable "engine_version" {
  description = "MySQL engine version. Ignored when is_replica = true (replica inherits from primary)."
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "RDS instance class. db.t3.micro for dev; db.r6g.large or larger for production."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Storage size in GB. Ignored when is_replica = true."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the initial database. Ignored when is_replica = true."
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Master database username. Sensitive. Ignored when is_replica = true."
  type        = string
  sensitive   = true
  default     = ""
}


variable "subnet_ids" {
  description = "Private subnet IDs for the DB subnet group. Must span at least two AZs for Multi-AZ."
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the RDS security group"
  type        = string
}

variable "app_security_group_id" {
  description = "Security group ID of the application tier. RDS only accepts MySQL connections from this SG."
  type        = string
  # No default — forcing the caller to explicitly pass the app SG prevents
  # accidentally making the database accessible from other sources.
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment. Provides AZ-level fault tolerance with automatic failover. true for primary; false for replicas."
  type        = bool
  default     = true
}

variable "is_replica" {
  description = "Set to true when creating a cross-region read replica. Changes which arguments are passed to the RDS instance."
  type        = bool
  default     = false
}

variable "replicate_source_db" {
  description = "ARN of the primary RDS instance to replicate from. Required when is_replica = true. Format: arn:aws:rds:<region>:<account>:db:<identifier>"
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "KMS key ARN, key ID, or alias for encrypting the DB instance. Required for cross-region encrypted replicas; defaults to the AWS-managed RDS key if not set."
  type        = string
  default     = null
}

variable "backup_retention_days" {
  description = "Days to retain automated backups. 0 disables backups (replicas only). Primary should be 7+."
  type        = number
  default     = 7
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "region" {
  description = "AWS region — embedded in resource names"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
  default = "null"
}