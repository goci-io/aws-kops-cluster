terraform {
  required_version = ">= 0.12.1"

  required_providers {
    null       = "~> 2.1"
    local      = "~> 1.3"
    kubernetes = "~> 1.8"
  }
}

provider "aws" {
  version = "~> 2.25"

  assume_role {
    role_arn = var.aws_assume_role_arn
  }
}
