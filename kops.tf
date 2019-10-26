
locals {
  kops_env_config = {
    KOPS_STATE_STORE      = "s3://${aws_s3_bucket.kops_state.id}"
    KOPS_CLUSTER_NAME     = local.cluster_name
    AWS_ACCESS_KEY_ID     = var.external_account ? join("", aws_iam_access_key.kops.*.id) : ""
    AWS_SECRET_ACCESS_KEY = var.external_account ? join("", aws_iam_access_key.kops.*.secret) : ""
    AWS_DEFAULT_REGION    = local.aws_region
  }

  kops_cluster_config = templatefile("${path.module}/templates/cluster.yaml", {
    cluster_name          = local.cluster_name
    cluster_dns           = local.cluster_dns
    cluster_zone_id       = local.cluster_zone_id
    dns_type              = var.cluster_dns_type
    cluster_cidr          = "100.0.0.0/8"
    namespace             = var.namespace
    stage                 = var.stage
    region                = var.region
    aws_region            = local.aws_region
    kops_bucket_name      = aws_s3_bucket.kops_state.id
    vpc_id                = local.vpc_id
    vpc_cidr              = local.vpc_cidr
    certificate_arn       = local.certificate_arn
    lb_security_groups    = ""
    create_api_lb         = local.external_lb_enabled
    public_subnet_id_a    = local.public_subnet_id_a
    public_subnet_cidr_a  = local.public_subnet_cidr_a
    public_subnet_id_b    = local.public_subnet_id_b
    public_subnet_cidr_b  = local.public_subnet_cidr_b
    public_subnet_id_c    = local.public_subnet_id_c
    public_subnet_cidr_c  = local.public_subnet_cidr_c
    private_subnet_id_a   = local.private_subnet_id_a
    private_subnet_cidr_a = local.private_subnet_cidr_a
    private_subnet_id_b   = local.private_subnet_id_b
    private_subnet_cidr_b = local.private_subnet_cidr_b
    private_subnet_id_c   = local.private_subnet_id_c
    private_subnet_cidr_c = local.private_subnet_cidr_c

    max_requests_in_flight          = var.max_requests_in_flight
    max_mutating_requests_in_flight = var.max_mutating_requests_in_flight
  })

  kops_default_image = "kope.io/k8s-1.12-debian-stretch-amd64-hvm-ebs-2019-06-21"
  kops_configs = concat(
    [
      { name = "cluster", rendered = local.kops_cluster_config },
      data.null_data_source.bastion_instance_group.outputs,
    ],
    data.null_data_source.master_instance_groups.*.outputs,
    data.null_data_source.instance_groups.*.outputs,
  )
}

module "ssh_key_pair" {
  source              = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=tags/0.4.0"
  namespace           = var.namespace
  stage               = var.stage
  attributes          = local.attributes
  tags                = local.tags
  ssh_public_key_path = var.ssh_path
  generate_ssh_key    = "true"
  name                = "kops"
}

resource "null_resource" "replace_config" {
  count = length(local.kops_configs)

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "echo \"${local.kops_configs[count.index].rendered}\" | kops replace --force -f -"
  }

  triggers = {
    name = local.kops_configs[count.index].name
    hash = md5(local.kops_configs[count.index].rendered)
  }
}

resource "null_resource" "kops_update_cluster" {
  depends_on = [null_resource.replace_config]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = <<EOF
      kops create secret sshpublickey admin -i ${module.ssh_key_pair.public_key_filename};
      kops update cluster --yes
EOF
  }

  triggers = {
    hash = md5(jsonencode(local.kops_configs))
  }
}
/*
resource "null_resource" "export_kubecfg" {
  provisioner "local-exec" {
    command     = "kops export kubecfg"
    environment = local.kops_env_config
  }

  triggers = {
    hash = md5(jsonencode(local.kops_configs))
  }
}
*/
resource "null_resource" "kops_delete_cluster" {
  provisioner "local-exec" {
    when        = "destroy"
    command     = "kops delete cluster --yes"
    environment = local.kops_env_config
  }
}
