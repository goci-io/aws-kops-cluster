
locals {
  kops_env_config = {
    KOPS_CLUSTER_NAME     = local.cluster_dns
    KOPS_STATE_STORE      = "s3://${aws_s3_bucket.kops_state.id}"
    AWS_ACCESS_KEY_ID     = var.external_account ? join("", aws_iam_access_key.kops.*.id) : ""
    AWS_SECRET_ACCESS_KEY = var.external_account ? join("", aws_iam_access_key.kops.*.secret) : ""
    AWS_DEFAULT_REGION    = local.aws_region
  }

  kops_cluster_config = templatefile("${path.module}/templates/cluster.yaml", {
    cluster_name            = local.cluster_name
    cluster_dns             = local.cluster_dns
    cluster_zone_id         = local.cluster_zone_id
    dns_type                = var.cluster_dns_type
    k8s_version             = var.kubernetes_version
    cluster_cidr            = "100.0.0.0/8"
    namespace               = var.namespace
    stage                   = var.stage
    region                  = var.region
    aws_region              = local.aws_region
    kops_bucket_name        = aws_s3_bucket.kops_state.id
    vpc_id                  = local.vpc_id
    vpc_cidr                = local.vpc_cidr
    service_cluster_ip_cidr = cidrsubnet("100.0.0.0/8", 6, 0)
    certificate_arn         = local.certificate_arn
    lb_security_groups      = ""
    create_api_lb           = !local.external_lb_enabled
    public_subnet_id_a      = local.public_subnet_id_a
    public_subnet_cidr_a    = local.public_subnet_cidr_a
    public_subnet_id_b      = local.public_subnet_id_b
    public_subnet_cidr_b    = local.public_subnet_cidr_b
    public_subnet_id_c      = local.public_subnet_id_c
    public_subnet_cidr_c    = local.public_subnet_cidr_c
    private_subnet_id_a     = local.private_subnet_id_a
    private_subnet_cidr_a   = local.private_subnet_cidr_a
    private_subnet_id_b     = local.private_subnet_id_b
    private_subnet_cidr_b   = local.private_subnet_cidr_b
    private_subnet_id_c     = local.private_subnet_id_c
    private_subnet_cidr_c   = local.private_subnet_cidr_c
    etcd_members            = data.null_data_source.master_info.*.outputs.name
    etcd_main_volume_type   = var.etcd_main_storage_type
    etcd_main_volume_iops   = var.etcd_main_storage_iops
    etcd_main_volume_size   = var.etcd_main_storage_size
    etcd_event_volume_type  = var.etcd_events_storage_type
    etcd_event_volume_iops  = var.etcd_events_storage_iops
    etcd_event_volume_size  = var.etcd_events_storage_size

    max_requests_in_flight          = var.max_requests_in_flight
    max_mutating_requests_in_flight = var.max_mutating_requests_in_flight
  })

  kops_default_image = "kope.io/k8s-1.12-debian-stretch-amd64-hvm-ebs-2019-06-21"
  kops_configs = concat(
    [data.null_data_source.bastion_instance_group.outputs],
    data.null_data_source.master_instance_groups.*.outputs,
    data.null_data_source.instance_groups.*.outputs,
  )

  kops_triggers = {
    cluster_hash = md5(jsonencode(local.kops_cluster_config))
    igs_hash     = md5(jsonencode(local.kops_configs))
  }
}

module "ssh_key_pair" {
  source              = "git::https://github.com/cloudposse/terraform-aws-key-pair.git?ref=tags/0.4.0"
  namespace           = var.namespace
  stage               = var.stage
  attributes          = local.attributes
  tags                = local.tags
  ssh_public_key_path = format("%s/ssh", var.secrets_path)
  generate_ssh_key    = "true"
  name                = "kops"
}

resource "null_resource" "replace_cluster" {
  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "echo \"${local.kops_cluster_config}\" | kops replace --force -f -"
  }

  triggers = local.kops_triggers
}

resource "null_resource" "replace_config" {
  count      = length(local.kops_configs)
  depends_on = [null_resource.replace_cluster]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "echo \"${local.kops_configs[count.index].rendered}\" | kops replace --force -f -"
  }

  triggers = {
    name = local.kops_configs[count.index].name
    hash = md5(local.kops_configs[count.index].rendered)
  }
}

resource "local_file" "ssl_private_key" {
  count             = local.custom_certificate_enabled ? 1 : 0
  filename          = "${var.secrets_path}/pki/key.pem"
  sensitive_content = local.certificate_private_key_pem
}

resource "local_file" "ssl_cert" {
  count             = local.custom_certificate_enabled ? 1 : 0
  filename          = "${var.secrets_path}/pki/ca.pem"
  sensitive_content = local.certificate_ca_pem
}

resource "null_resource" "api_ssl" {
  count = local.custom_certificate_enabled ? 1 : 0

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "kops create secret keypair ca --cert ${join("", local_file.ssl_cert.*.filename)} --key ${join("", local_file.ssl_private_key.*.filename)}"
  }

  triggers = {
    hash = md5(join("", local_file.ssl_cert.*.sensitive_content))
  }
}


resource "null_resource" "kops_update_cluster" {
  depends_on = [
    null_resource.replace_cluster,
    null_resource.replace_config,
    null_resource.api_ssl,
  ]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = <<EOF
      kops create secret sshpublickey admin -i ${module.ssh_key_pair.public_key_filename};
      kops update cluster --yes
EOF
  }

  triggers = local.kops_triggers
}

resource "null_resource" "kops_delete_cluster" {
  provisioner "local-exec" {
    when        = "destroy"
    command     = "kops delete cluster --yes"
    environment = local.kops_env_config
  }
}
