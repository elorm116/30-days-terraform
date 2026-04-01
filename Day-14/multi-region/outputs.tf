output "primary_bucket_name" {
  description = "Primary bucket name — us-east-1"
  value       = aws_s3_bucket.primary.id
}

output "primary_bucket_arn" {
  description = "Primary bucket ARN"
  value       = aws_s3_bucket.primary.arn
}

output "primary_bucket_region" {
  description = "Primary bucket region"
  value       = aws_s3_bucket.primary.region
}

output "replica_bucket_name" {
  description = "Replica bucket name — us-west-2"
  value       = aws_s3_bucket.replica.id
}

output "replica_bucket_arn" {
  description = "Replica bucket ARN"
  value       = aws_s3_bucket.replica.arn
}

output "replica_bucket_region" {
  description = "Replica bucket region"
  value       = aws_s3_bucket.replica.region
}

output "replication_role_arn" {
  description = "IAM role ARN used for S3 replication"
  value       = aws_iam_role.replication.arn
}