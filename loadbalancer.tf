
data "aws_route53_zone" "public_cluster_zone" {
  count        = local.cluster_dns == "" ? 0 : 1
  name         = format("%s.", local.cluster_dns)
  private_zone = false
}

locals {
  # Deploy additional public loadbalancer
  # This covers a setup where a private and public hosted zone exists and the API Server should be publicly available
  create_additional_loadbalancer = var.create_public_api_loadbalancer && (!local.external_lb_enabled || var.cluster_dns_type != "Private")
  api_log_prefix                 = "api/logs/${local.cluster_dns}"
}

module "api_loadbalancer_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context    = module.label.context
  attributes = ["api"]
}

resource "aws_security_group" "public_loadbalancer" {
  count       = local.create_additional_loadbalancer ? 1 : 0
  name        = "public-api.${local.cluster_dns}"
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

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb" "public_api" {
  count                      = local.create_additional_loadbalancer && !var.enable_classic_api_loadbalancer ? 1 : 0
  name                       = module.api_loadbalancer_label.id
  tags                       = module.api_loadbalancer_label.tags
  security_groups            = aws_security_group.public_loadbalancer.*.id
  load_balancer_type         = var.public_api_loadbalancer_type
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
  count    = local.create_additional_loadbalancer && !var.enable_classic_api_loadbalancer ? 1 : 0
  name     = module.api_loadbalancer_label.id
  tags     = module.api_loadbalancer_label.tags
  vpc_id   = local.vpc_id
  protocol = "HTTPS"
  port     = 443

  dynamic "health_check" {
    for_each = var.public_api_loadbalancer_type == "application" ? [1] : []

    content {
      enabled  = true
      path     = "/"
      protocol = "HTTPS"
      matcher  = "200-499"
    }
  }

  dynamic "health_check" {
    for_each = var.public_api_loadbalancer_type != "application" ? [1] : []
    
    content {
      enabled  = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "api" {
  count             = local.create_additional_loadbalancer && !var.enable_classic_api_loadbalancer ? 1 : 0
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

resource "aws_elb" "classic_public_api" {
  count                       = local.create_additional_loadbalancer && var.enable_classic_api_loadbalancer ? 1 : 0
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

resource "aws_route53_record" "public_api" {
  count   = local.create_additional_loadbalancer ? 1 : 0
  zone_id = join("", data.aws_route53_zone.public_cluster_zone.*.zone_id)
  name    = format("%s.%s", var.public_api_record_name, var.cluster_dns)
  type    = "A"
  
  alias {
    name                   = coalesce(join("", aws_lb.public_api.*.dns_name), join("", aws_elb.classic_public_api.*.dns_name))
    zone_id                = coalesce(join("", aws_lb.public_api.*.zone_id), join("", aws_elb.classic_public_api.*.zone_id))
    evaluate_target_health = true
  }
}
