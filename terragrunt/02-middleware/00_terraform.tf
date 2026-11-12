terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }
  required_version = "~> 1.11"

  backend "s3" {
    bucket       = "camptocamp-aws-is-training-terraform-state"
    key          = "github.com/vampouille/cloudnative-pg-anonymizer-lab/terragrunt/02-middleware/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    profile      = "c2c-is-training"
  }
}
