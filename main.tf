
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  attributes         = concat(var.attributes, [var.region])
  tags               = merge(var.tags, map("Cluster", local.cluster_name))
  cluster_name       = format("%s.%s.%s", var.stage, var.region, var.namespace)
  aws_region         = var.aws_region == "" ? data.aws_region.current.name : var.aws_region
  aws_account_id     = var.aws_account_id == "" ? data.aws_caller_identity.current.account_id : var.aws_account_id
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  namespace  = var.namespace
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = local.attributes
  tags       = local.tags
}

module "kops_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.label.context
  name       = "kops"
}
