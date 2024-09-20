terraform {
  required_version = ">= 1.4.4"

  required_providers {
    aws = {
      version = ">= 4.67.0"
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    profile        = "platform-tools"
    bucket         = "terraform-platform-state-platform-tools"
    key            = "terraform-tools/prod/nginx-dbt-platform.tfstate"
    region         = "eu-west-2"
    encrypt        = true
    kms_key_id     = "alias/terraform-platform-state-s3-key-platform-tools"
    dynamodb_table = "terraform-platform-lockdb-platform-tools"
  }
}

variable "platform-tools" {
  type    = map(string)
  default = {}
}

provider "aws" {
  alias                    = "platform-tools"
  shared_credentials_files = [var.platform-tools["aws_shared_credentials_file"]]
  profile                  = var.platform-tools["aws_profile"]
  region                   = "eu-west-2"
}

module "platform-tools-codebuild-nginx-dbt-platform-image" {
  source = "./codebuild"

  enable_scheduler    = false
  enable_webhook      = true
  privileged_mode     = true
  project_description = "DBT Platform nginx reverse proxy"
  project_name        = "build-nginx-dbt-platform-image-to-ecr"
  attached_policies   = local.attached_policies

  github = {
    branch     = null
    buildspec  = null
    repository = "https://github.com/uktrade/nginx-dbt-platform.git"
  }

  webhook_filters = [
    [
      {
        type    = "EVENT"
        pattern = "PUSH"
      }
    ]
  ]

  providers = {
    aws = aws.platform-tools
  }
}
