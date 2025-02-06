terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  backend "s3" { }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.region
  profile = var.aws_profile
}
