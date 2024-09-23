terraform {
  required_version = ">= 1.4.4"

  required_providers {
    aws = {
      version = ">= 4.67.0"
      source  = "hashicorp/aws"
    }
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
