terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = "~> 1.11"

  backend "s3" {
    bucket       = "camptocamp-aws-is-training-terraform-state"
    key          = "github.com/vampouille/cloudnative-pg-anonymizer-lab/terragrunt/03-app/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    profile      = "c2c-is-training"
  }
}
