terraform {
  required_version = ">= 0.12.1"

  required_providers {
    aws     = "~> 2.25"
    null    = "~> 2.1"
    local   = "~> 1.3"
  }
}

locals {
  tags         = merge(var.tags, map("Cluster", local.cluster_name))
  cluster_name = format("%s.%s.%s", var.stage, var.region, var.root_domain)
}

module "label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  namespace  = var.namespace
  name       = var.name
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = local.tags
}
