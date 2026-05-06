terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.devops_practice
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "biswajit"
    }
  }
}