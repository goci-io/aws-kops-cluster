terraform {
  required_version = ">= 0.12.1"

  required_providers {
    aws   = "~> 2.50"
    null  = "~> 2.1"
    local = "~> 1.3"
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  attributes     = concat(var.attributes, [var.region])
  tags           = merge(var.tags, map("KubernetesCluster", local.cluster_name))
  cluster_name   = format("%s.%s.%s", var.stage, var.region, var.namespace)
  aws_region     = var.aws_region == "" ? data.aws_region.current.name : var.aws_region
  aws_account_id = var.aws_account_id == "" ? data.aws_caller_identity.current.account_id : var.aws_account_id
}

data "aws_route53_zone" "cluster_zone" {
  count        = local.cluster_dns == "" ? 0 : 1
  name         = format("%s.", local.cluster_dns)
  private_zone = var.cluster_dns_type == "Private"
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  namespace  = var.namespace
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = local.attributes
  tags       = local.tags
}

module "kops_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context = module.label.context
  name    = "kops"
}
