terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# networking.region — pinned explicitly rather than relying on the AWS_REGION env var the
# pipeline's OIDC credentials step sets, so a plan run outside that step still targets the
# region the request actually asked for.
provider "aws" {
  region = var.region
}
