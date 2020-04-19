
data "terraform_remote_state" "vpc" {
  count   = var.vpc_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.vpc_module_state
  }
}

data "terraform_remote_state" "acm" {
  count   = local.acm_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = local.acm_module_state
  }
}

data "terraform_remote_state" "dns" {
  count   = var.dns_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.dns_module_state
  }
}

data "terraform_remote_state" "loadbalancer" {
  count   = var.loadbalancer_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.loadbalancer_module_state
  }
}
/*
data "terraform_remote_state" "custom_cert" {
  count   = local.custom_certificate_enabled ? 1 : 0
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.api_cert_module_state
  }
}
*/

data "aws_route53_zone" "cluster_zone" {
  count        = local.cluster_dns == "" ? 0 : 1
  name         = format("%s.", local.cluster_dns)
  private_zone = var.cluster_dns_type == "Private"
}

locals {
  acm_module_state = var.acm_module_state == "" && var.dns_module_state != "" && var.certificate_arn == "" ? var.dns_module_state : var.acm_module_state

  vpc_id          = var.vpc_id == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_id : var.vpc_id
  vpc_cidr        = var.vpc_cidr == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_cidr : var.vpc_cidr
  certificate_arn = var.certificate_arn == "" ? data.terraform_remote_state.acm[0].outputs.certificate_arn : var.certificate_arn
  cluster_dns     = var.cluster_dns == "" ? data.terraform_remote_state.dns[0].outputs.domain_name : var.cluster_dns
  cluster_zone_id = join("", data.aws_route53_zone.cluster_zone.*.zone_id)

  public_subnet_ids    = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.terraform_remote_state.vpc[0].outputs.public_subnet_ids
  private_subnet_ids   = length(var.private_subnet_ids) > 0 ? var.private_subnet_ids : data.terraform_remote_state.vpc[0].outputs.private_subnet_ids
  public_subnet_cidrs  = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : data.terraform_remote_state.vpc[0].outputs.public_subnet_cidrs
  private_subnet_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : data.terraform_remote_state.vpc[0].outputs.private_subnet_cidrs

  external_lb_enabled      = local.external_lb_target_arn != "" || local.external_lb_name_masters != ""
  external_lb_name_masters = var.master_loadbalancer_name == "" && length(data.terraform_remote_state.loadbalancer) > 0 ? lookup(data.terraform_remote_state.loadbalancer[0].outputs, "loadbalancer_name", "") : var.master_loadbalancer_name
  external_lb_target_arn   = var.master_loadbalancer_target_arn == "" && length(data.terraform_remote_state.loadbalancer) > 0 ? lookup(data.terraform_remote_state.loadbalancer[0].outputs, "loadbalancer_target_arn", "") : var.master_loadbalancer_target_arn

  #custom_certificate_enabled  = var.api_cert_module_state != ""
  #certificate_ca_pem          = join("", data.terraform_remote_state.custom_cert.*.outputs.certificate_ca_cert)
  #certificate_ca_key_pem      = join("", data.terraform_remote_state.custom_cert.*.outputs.certificate_ca_key)
}
