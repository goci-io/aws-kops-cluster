locals {
  api_log_prefix = "api/logs/${local.cluster_dns}"
}

module "api_loadbalancer_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context    = module.label.context
  attributes = ["api"]
}

resource "aws_elb" "public_api" {
  count                       = var.create_public_api_record ? 1 : 0
  name                        = module.api_loadbalancer_label.id
  tags                        = module.api_loadbalancer_label.tags
  subnets                     = local.public_subnet_ids
  security_groups             = aws_security_group.public_loadbalancer.*.id
  connection_draining         = true
  cross_zone_load_balancing   = true
  internal                    = false
  idle_timeout                = 900

  listener {
    lb_port            = 443
    lb_protocol        = "SSL"
    instance_port      = 443
    instance_protocol  = "SSL"
    ssl_certificate_id = local.certificate_arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "SSL:443"
    interval            = 30
  }

  access_logs {
    bucket        = aws_s3_bucket.kops_state.id
    bucket_prefix = "${local.api_log_prefix}/public"
    enabled       = true
  }
}

module "public_api_record" {
  source        = "git::https://github.com/goci-io/aws-route53-records.git?ref=master"
  enabled       = var.create_public_api_record
  hosted_zone   = local.cluster_dns
  alias_records = [
    {
      name       = var.public_record_name
      alias      = join("", aws_elb.public_api.*.dns_name)
      alias_zone = join("", aws_elb.public_api.*.zone_id)
    }
  ]
}
