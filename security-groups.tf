
module "masters_sg_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context = module.label.context
  name    = "masters"
}

module "nodes_sg_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.16.0"
  context = module.label.context
  name    = "nodes"
}

locals {
  additional_public_loadbalancer_sg = local.create_additional_loadbalancer ? [{
    security_groups = aws_security_group.public_loadbalancer.*.id
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
  }] : []

  security_default_rules = yamldecode(templatefile("${path.module}/templates/security-groups.yaml", {
    nodes_sg   = aws_security_group.nodes.id
    masters_sg = aws_security_group.masters.id
  }))
  
  nodes_security_ingress   = concat(var.additional_node_ingress, local.security_default_rules.nodes)
  masters_security_ingress = concat(var.additional_master_ingress, local.additional_public_loadbalancer_sg, local.security_default_rules.masters)
}

resource "aws_security_group" "masters" {
  name        = module.masters_sg_label.id
  tags        = module.masters_sg_label.tags
  description = "Controls traffic to the master nodes of cluster ${local.cluster_name}"
  vpc_id      = local.vpc_id

  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "masters_ingress" {
  count             = length(local.masters_security_ingress)
  type              = "ingress"
  security_group_id = aws_security_group.masters.id
  to_port           = local.masters_security_ingress[count.index].to_port
  from_port         = local.masters_security_ingress[count.index].from_port
  self              = lookup(local.masters_security_ingress[count.index], "self", false)
  protocol          = lookup(local.masters_security_ingress[count.index], "protocol", "tcp")
  cidr_blocks       = lookup(local.masters_security_ingress[count.index], "cidr_blocks", [])
  security_groups   = lookup(local.masters_security_ingress[count.index], "security_groups", [])
  description       = lookup(local.masters_security_ingress[count.index], "description", "Managed by Terraform")
}

resource "aws_security_group" "nodes" {
  name        = module.nodes_sg_label.id
  tags        = module.nodes_sg_label.tags
  description = "Controls traffic to the worker nodes of cluster ${local.cluster_name}"
  vpc_id      = local.vpc_id

  egress {
    to_port     = 0
    from_port   = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "nodes_ingress" {
  count             = length(local.nodes_security_ingress)
  type              = "ingress"
  security_group_id = aws_security_group.nodes.id
  to_port           = local.nodes_security_ingress[count.index].to_port
  from_port         = local.nodes_security_ingress[count.index].from_port
  self              = lookup(local.nodes_security_ingress[count.index], "self", false)
  protocol          = lookup(local.nodes_security_ingress[count.index], "protocol", "tcp")
  cidr_blocks       = lookup(local.nodes_security_ingress[count.index], "cidr_blocks", [])
  security_groups   = lookup(local.nodes_security_ingress[count.index], "security_groups", [])
  description       = lookup(local.nodes_security_ingress[count.index], "description", "Managed by Terraform")
}