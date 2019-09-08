
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
    vpc_id           = local.vpc_id
    vpc_cidr         = local.vpc_cidr
    certificate_arn  = local.certificate_arn
    security_groups  = ""
    public_subnet_id_a    = ""
    public_subnet_cidr_a  = ""
    public_subnet_id_b    = ""
    public_subnet_cidr_b  = ""
    public_subnet_id_c    = ""
    public_subnet_cidr_c  = ""
    private_subnet_id_a   = ""
    private_subnet_cidr_a = ""
    private_subnet_id_b   = ""
    private_subnet_cidr_b = ""
    private_subnet_id_c   = ""
    private_subnet_cidr_c = ""
  })
}

data "null_data_source" "instance_groups" {
  count = length(var.instance_groups) * var.max_availability_zones

  inputs = {
    rendered = templatefile("${path.module}/templates/instance-group.yaml", {
      cluster_name           = local.cluster_name
      namespace              = var.namespace
      stage                  = var.stage
      region                 = var.region
      aws_availability_zone  = data.aws_availability_zones.available[count.index % var.max_availability_zones].name
      image                  = lookup(var.instance_groups[count.index], "image", "kope.io/k8s-1.12-debian-stretch-amd64-hvm-ebs-2019-06-21")
      instance_type          = lookup(var.instance_groups[count.index], "instance_type")
      instance_max           = lookup(var.instance_groups[count.index], "count_max", 3)
      instance_min           = lookup(var.instance_groups[count.index], "count_min", 1)
      node_role              = lookup(var.instance_groups[count.index], "node_role", "Node")
      storage_type           = lookup(var.instance_groups[count.index], "storage_type", "gp2")
      storage_iops           = lookup(var.instance_groups[count.index], "storage_iops", 288)
      storage_in_gb          = lookup(var.instance_groups[count.index], "storage_in_gb", 96)
      autospotting_enabled   = lookup(var.instance_groups[count.index], "autospotting", lookup(var.instance_groups[count.index], "type") == "Node" ? true : false)
      autospotting_max_price = lookup(var.instance_groups[count.index], "autospotting_max_price", "0.01")
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
  count = length(var.instance_groups) * var.max_availability_zones

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
