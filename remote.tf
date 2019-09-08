
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
}
