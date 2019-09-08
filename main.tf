terraform {
  required_version = ">= 0.12.1"

  required_providers {
    aws        = "~> 2.25"
    local      = "~> 1.3"
    kubernetes = "~> 1.8"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  attributes     = concat(var.attributes, [var.region])
  tags           = merge(var.tags, map("Cluster", local.cluster_name))
  cluster_name   = format("%s.%s.%s", var.stage, var.region, var.root_domain)
  cluster_dns    = var.cluster_dns == "" ? local.cluster_name : var.cluster_dns
  aws_region     = var.aws_region == "" ? data.aws_region.current.name : var.aws_region
  aws_account_id = var.aws_account_id == "" ? data.aws_caller_identity.current.account_id : var.aws_account_id
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  namespace  = var.namespace
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = local.attributes
  tags       = local.tags
}
