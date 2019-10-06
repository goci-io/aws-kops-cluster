
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

data "aws_route53_zone" "cluster_zone" {
  count        = var.cluster_dns == "" ? 0 : 1
  name         = format("%s.", var.cluster_dns)
  private_zone = var.cluster_dns_type == "Private"
}

locals {
  acm_module_state = var.acm_module_state == "" && var.dns_module_state != "" && var.certificate_arn == "" ? var.dns_module_state : var.acm_module_state

  vpc_id          = var.vpc_id == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_id : var.vpc_id
  vpc_cidr        = var.vpc_cidr == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_cidr : var.vpc_cidr
  certificate_arn = var.certificate_arn == "" ? data.terraform_remote_state.acm[0].outputs.certificate_arn : var.certificate_arn
  cluster_dns     = var.cluster_dns == "" ? data.terraform_remote_state.dns[0].outputs.domain_name : var.cluster_dns
  cluster_zone_id = var.cluster_dns == "" ? data.terraform_remote_state.dns[0].outputs.zone_id : join("", data.aws_route53_zone.cluster_zone.*.zone_id)

  public_subnet_id_a   = var.public_subnet_id_a == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_ids[0] : var.public_subnet_id_a
  public_subnet_cidr_a = var.public_subnet_cidr_a == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_cidrs[0] : var.public_subnet_cidr_a

  public_subnet_id_b   = var.public_subnet_id_b == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_ids[1] : var.public_subnet_id_b
  public_subnet_cidr_b = var.public_subnet_cidr_b == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_cidrs[1] : var.public_subnet_cidr_b

  public_subnet_id_c   = var.public_subnet_id_c == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_ids[2] : var.public_subnet_id_c
  public_subnet_cidr_c = var.public_subnet_cidr_c == "" ? data.terraform_remote_state.vpc[0].outputs.public_subnet_cidrs[2] : var.public_subnet_cidr_c

  private_subnet_id_a   = var.private_subnet_id_a == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_ids[0] : var.private_subnet_id_a
  private_subnet_cidr_a = var.private_subnet_cidr_a == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_cidrs[0] : var.private_subnet_cidr_a

  private_subnet_id_b   = var.private_subnet_id_b == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_ids[1] : var.private_subnet_id_b
  private_subnet_cidr_b = var.private_subnet_cidr_b == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_cidrs[1] : var.private_subnet_cidr_b

  private_subnet_id_c   = var.private_subnet_id_c == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_ids[2] : var.private_subnet_id_c
  private_subnet_cidr_c = var.private_subnet_cidr_c == "" ? data.terraform_remote_state.vpc[0].outputs.private_subnet_cidrs[2] : var.private_subnet_cidr_b

  external_lb_name_masters = var.master_loadbalancer_name == "" && length(data.terraform_remote_state.loadbalancer) > 0 ? data.terraform_remote_state.loadbalancer.outputs.loadbalancer_name : var.master_loadbalancer_name
  external_lb_target_arn   = var.master_loadbalancer_target_arn == "" && length(data.terraform_remote_state.loadbalancer) > 0 ? data.terraform_remote_state.loadbalancer.outputs.loadbalancer_target_arn : var.master_loadbalancer_target_arn
}
