
locals {
  kops_env_config = {
    KOPS_CLUSTER_NAME     = local.cluster_dns
    KOPS_STATE_STORE      = "s3://${aws_s3_bucket.kops_state.id}"
    AWS_ACCESS_KEY_ID     = var.external_account ? join("", aws_iam_access_key.kops.*.id) : ""
    AWS_SECRET_ACCESS_KEY = var.external_account ? join("", aws_iam_access_key.kops.*.secret) : ""
    AWS_DEFAULT_REGION    = local.aws_region
  }

  kops_cluster_config = templatefile("${path.module}/templates/cluster.yaml", {
    cluster_name           = local.cluster_name
    cluster_dns            = local.cluster_dns
    cluster_zone_id        = local.cluster_zone_id
    dns_type               = var.cluster_dns_type
    k8s_version            = var.kubernetes_version
    etcd_version           = var.etcd_version
    cluster_cidr           = "100.64.0.0/10"
    namespace              = var.namespace
    stage                  = var.stage
    region                 = var.region
    addons                 = var.kops_addons
    aws_region             = local.aws_region
    aws_zones              = slice(data.aws_availability_zones.available.names, 0, var.max_availability_zones)
    kops_bucket_name       = aws_s3_bucket.kops_state.id
    vpc_id                 = local.vpc_id
    vpc_cidr               = local.vpc_cidr
    ssh_access             = length(var.ssh_access_cidrs) > 0 ? var.ssh_access_cidrs : [local.vpc_cidr]
    api_access             = distinct(concat(var.create_public_api_record ? ["0.0.0.0/0"] : [], length(var.api_access_cidrs) > 0 ? var.api_access_cidrs : [var.cluster_dns_type != "Private" ? "0.0.0.0/0" : local.vpc_cidr]))
    certificate_arn        = local.certificate_arn
    lb_type                = var.cluster_dns_type == "Private" ? "Internal" : "Public"
    bastion_public_name    = var.bastion_public_name
    public_subnet_ids      = local.public_subnet_ids
    private_subnet_ids     = local.private_subnet_ids
    public_subnet_cidrs    = local.public_subnet_cidrs
    private_subnet_cidrs   = local.private_subnet_cidrs
    etcd_members           = data.null_data_source.master_info.*.outputs.name
    etcd_main_volume_type  = var.etcd_main_storage_type
    etcd_main_volume_iops  = var.etcd_main_storage_iops
    etcd_main_volume_size  = var.etcd_main_storage_size
    etcd_event_volume_type = var.etcd_events_storage_type
    etcd_event_volume_iops = var.etcd_events_storage_iops
    etcd_event_volume_size = var.etcd_events_storage_size

    max_requests_in_flight          = var.max_requests_in_flight
    max_mutating_requests_in_flight = var.max_mutating_requests_in_flight

    has_external_policies      = length(var.external_master_policies) > 0
    external_master_policies   = var.external_master_policies
    additional_master_policies = var.additional_master_policies == "" ? "" : indent(6, var.additional_master_policies)

    openid_connect_enabled = var.openid_connect_enabled
    oidc_issuer_url        = var.oidc_issuer_url
    oidc_client_id         = var.oidc_client_id
    oidc_username_claim    = var.oidc_username_claim
    oidc_username_prefix   = var.oidc_username_prefix
    oidc_groups_claim      = var.oidc_groups_claim
    oidc_groups_prefix     = var.oidc_groups_prefix
    oidc_ca_file           = var.oidc_ca_file
    oidc_ca_content        = var.oidc_ca_content
    oidc_required_claims   = var.oidc_required_claims
  })

  kops_configs = concat(
    [data.null_data_source.bastion_instance_group.outputs],
    data.null_data_source.master_instance_groups.*.outputs,
    data.null_data_source.instance_groups.*.outputs,
  )

  kops_triggers = {
    cluster  = jsonencode(local.kops_cluster_config)
    igs_hash = md5(jsonencode(local.kops_configs))
  }
}

module "ssh_key_pair" {
  source              = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=tags/0.9.0"
  namespace           = var.namespace
  stage               = var.stage
  attributes          = local.attributes
  tags                = local.tags
  ssh_public_key_path = format("%s/ssh", var.secrets_path)
  generate_ssh_key    = "true"
  name                = "kops"
}

resource "null_resource" "replace_cluster" {
  depends_on = [
    null_resource.wait_for_iam,
    aws_s3_bucket_public_access_block.block,
  ]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "echo -e ${self.triggers.cluster} | kops replace --force -f -"
  }

  triggers = local.kops_triggers
}

resource "null_resource" "replace_config" {
  count      = length(local.kops_configs)
  depends_on = [null_resource.replace_cluster]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "echo -e \"${self.triggers.content}\" | kops replace --force -f -"
  }

  triggers = {
    content = local.kops_configs[count.index].rendered
  }
}

resource "null_resource" "kops_update_cluster" {
  depends_on = [
    null_resource.replace_cluster,
    null_resource.replace_config,
  ]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = <<EOF
      kops create secret sshpublickey admin -i ${self.triggers.key_filename};
      kops update cluster --yes
EOF
  }

  triggers = merge(local.kops_triggers, {
    key_filename = module.ssh_key_pair.public_key_filename
  })
}

resource "null_resource" "cluster_startup" {
  count = var.enable_kops_validation ? 1 : 0
  depends_on = [
    module.public_api_record.fqdn,
    null_resource.kops_update_cluster,
  ]

  provisioner "local-exec" {
    # This is only required during the initial setup
    environment = local.kops_env_config
    command     = "${self.triggers.path}/scripts/wait-for-cluster.sh"
  }

  triggers = {
    path = path.module
  }
}

resource "null_resource" "kops_delete_cluster" {
  provisioner "local-exec" {
    when        = destroy
    command     = "kops delete cluster --yes"
    environment = local.kops_env_config
  }
}
