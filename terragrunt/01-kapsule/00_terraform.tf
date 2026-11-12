terraform {
  required_providers {
    scaleway = {
      source = "scaleway/scaleway"
      version = "~> 2.73"
    }
		pass = {
			source = "mecodia/pass"
			version = "~> 3.1"
		}
  }
  required_version = "~> 1.11"

  backend "s3" {
    bucket       = "camptocamp-aws-is-training-terraform-state"
    key          = "github.com/vampouille/cloudnative-pg-anonymizer-lab/terragrunt/01-kapsule/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    profile      = "c2c-is-training"
  }
}
