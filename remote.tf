
data "terraform_remote_state" "vpc" {
  count   = var.vpc_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.vpc_module_state
  }
}

data "terraform_remote_state" "acm" {
  count   = var.acm_module_state == "" ? 0 : 1
  backend = "s3"

  config = {
    bucket = var.tf_bucket
    key    = var.acm_module_state
  }
}

locals {
  vpc_id          = var.vpc_id == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_id : var.vpc_id
  vpc_cidr        = var.vpc_cidr == "" ? data.terraform_remote_state.vpc[0].outputs.vpc_cidr : var.vpc_cidr
  certificate_arn = var.certificate_arn == "" ? data.terraform_remote_state.acm[0].outputs.certificate_arn : var.certificate_arn

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

  subnets = {
    private = [local.private_subnet_id_a, local.private_subnet_id_b, local.private_subnet_id_c],
    public  = [local.public_subnet_id_a, local.public_subnet_id_b, local.public_subnet_id_c]
  }
}
