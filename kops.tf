
locals {
  kops_env_config = {
    KOPS_STATE_STORE  = "s3://${aws_s3_bucket.kops_state.id}"
    KOPS_CLUSTER_NAME = local.cluster_name
  }

  kops_cluster_config = templatefile("${path.module}/templates/cluster.yaml", {
    cluster_name     = local.cluster_name
    cluster_dns      = local.cluster_dns
    cluster_cidr     = "100.0.0.0/8"
    namespace        = var.namespace
    stage            = var.stage
    region           = var.region
    aws_region       = local.aws_region
    kops_bucket_name = aws_s3_bucket.kops_state.id
    certificate_arn  = local.certificate_arn
    security_groups  = ""
  })
}

data "null_data_source" "instance_groups" {
  count = length(var.instance_groups)

  inputs = {
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      storage_type           = "gp2"
      aws_availability_zone  = data.aws_availability_zones.available[count.index].name
      instance_type          = lookup(var.instance_groups[count.index], "type")
      image                  = lookup(var.instance_groups[count.index], "image")
      instance_max           = lookup(var.instance_groups[count.index], "count_max")
      instance_min           = lookup(var.instance_groups[count.index], "count_min")
      node_role              = lookup(var.instance_groups[count.index], "node_role")
      storage_iops           = lookup(var.instance_groups[count.index], "storage_iops")
      storage_in_gb          = lookup(var.instance_groups[count.index], "storage_in_gb")
      autospotting_enabled   = lookup(var.instance_groups[count.index], "autospotting")
      autospotting_max_price = lookup(var.instance_groups[count.index], "autospotting_max_price")
      autoscaler             = lookup(var.instance_groups[count.index], "type") == "Node" ? "enabled" : "off"
    })
  }
}

module "ssh_key_pair" {
  source              = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=tags/0.4.0"
  namespace           = var.namespace
  stage               = var.stage
  attributes          = var.attributes
  tags                = local.tags
  ssh_public_key_path = var.ssh_path
  generate_ssh_key    = "true"
  name                = "kops"
}

resource "null_resource" "cluster" {
  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = <<EOF
      echo "${local.kops_cluster_config}" | kops replace --force -f -;
      kops create secret sshpublickey kops -i ${module.ssh_key_pair.public_key_filename};
      kops update cluster --yes
EOF
  }

  triggers = {
    hash = md5(local.kops_cluster_config)
  }
}

resource "null_resource" "instance_groups" {
  count = length(var.instance_groups)

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "kops update ig "
  }

  triggers = {
    hash = md5(jsonencode(data.null_data_source.instance_groups.*.outputs.rendered))
  }
}

resource "null_resource" "kops_delete_cluster" {
  provisioner "local-exec" {
    when        = "destroy"
    command     = "kops delete cluster --yes"
    environment = local.kops_env_config
  }
}
