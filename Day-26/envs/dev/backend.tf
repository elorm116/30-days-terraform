terraform {
  backend "s3" {
    bucket       = "dark-knight-terraform-state"
    key          = "day26/webserver-cluster/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    # Partial backend config - additional values passed via -backend-config at init time:
    #   terraform init \
    #     -backend-config="access_key=..." \
    #     -backend-config="secret_key=..."
    # Or use environment variables: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  }
}
