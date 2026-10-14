terraform {
  backend "s3" {
    # Values provided via -backend-config flag during terraform init
    # See: make tf-init ENV=dev
    # Backend config files: infra/environments/dev/backend.tfvars
  }
}
