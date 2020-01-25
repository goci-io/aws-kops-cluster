
data "aws_route53_zone" "public_cluster_zone" {
  count        = local.cluster_dns == "" ? 0 : 1
  name         = format("%s.", local.cluster_dns)
  private_zone = false
}

locals {
  # Deploy additional public loadbalancer
  # This covers a setup where a private and public hosted zone exists and the API Server should be publicly available
  create_additional_loadbalancer = var.create_api_loadbalancer && var.master_ips_for_private_api_dns && !local.external_lb_enabled
  api_log_prefix                 = "api/logs/${local.cluster_dns}"
}

module "api_loadbalancer_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.label.context
  attributes = ["api"]
}

resource "aws_security_group" "public_loadbalancer" {
  count       = local.create_additional_loadbalancer ? 1 : 0
  name        = module.api_loadbalancer_label.id
  tags        = module.api_loadbalancer_label.tags
  description = "Allows public HTTPS inbound traffic to API Server"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "public_api" {
  count                      = local.create_additional_loadbalancer ? 1 : 0
  name                       = module.api_loadbalancer_label.id
  tags                       = module.api_loadbalancer_label.tags
  security_groups            = aws_security_group.public_loadbalancer.*.id
  load_balancer_type         = var.api_loadbalancer_type
  subnets                    = local.public_subnet_ids
  internal                   = false
  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.kops_state.id
    prefix  = "${local.api_log_prefix}/public"
    enabled = true
  }
}

resource "aws_lb_target_group" "api" {
  count    = local.create_additional_loadbalancer ? 1 : 0
  name     = module.api_loadbalancer_label.id
  tags     = module.api_loadbalancer_label.tags
  vpc_id   = local.vpc_id
  protocol = "HTTPS"
  port     = 443
}

resource "aws_lb_listener" "api" {
  count             = local.create_additional_loadbalancer ? 1 : 0
  load_balancer_arn = join("", aws_lb.public_api.*.arn)
  certificate_arn   = local.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  protocol          = "HTTPS"
  port              = 443

  default_action {
    type             = "forward"
    target_group_arn = join("", aws_lb_target_group.api.*.arn)
  }
}

resource "aws_route53_record" "public_api" {
  zone_id = join("", data.aws_route53_zone.public_cluster_zone.*.zone_id)
  name    = format("%s.%s", var.api_record_name, var.cluster_dns)
  type    = "A"
  
  alias {
    name                   = join("", aws_lb.public_api.*.dns_name)
    zone_id                = join("", aws_lb.public_api.*.zone_id)
    evaluate_target_health = true
  }
}
