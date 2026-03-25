output "bucket_name" {
  description = "State bucket name — use this in all backend.hcl files"
  value       = aws_s3_bucket.tf_state.id
}