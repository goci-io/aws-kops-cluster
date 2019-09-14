
locals {
  kops_env_config = {
    KOPS_STATE_STORE      = "s3://${aws_s3_bucket.kops_state.id}"
    KOPS_CLUSTER_NAME     = local.cluster_name
    AWS_ACCESS_KEY_ID     = var.external_account ? join("", aws_iam_access_key.kops.*.id) : ""
    AWS_SECRET_ACCESS_KEY = var.external_account ? join("", aws_iam_access_key.kops.*.secret) : ""
  }

  kops_cluster_config = templatefile("${path.module}/templates/cluster.yaml", {
    cluster_name          = local.cluster_name
    cluster_dns           = local.cluster_dns
    cluster_cidr          = "100.0.0.0/8"
    namespace             = var.namespace
    stage                 = var.stage
    region                = var.region
    aws_region            = local.aws_region
    kops_bucket_name      = aws_s3_bucket.kops_state.id
    vpc_id                = local.vpc_id
    vpc_cidr              = local.vpc_cidr
    certificate_arn       = local.certificate_arn
    security_groups       = ""
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
  })

  kops_default_image = "kope.io/k8s-1.12-debian-stretch-amd64-hvm-ebs-2019-06-21"
  yaml_new_doc       = "---\n"
  kops_cluster = format(
    "%s%s%s%s%s%s%s",
    local.kops_cluster_config,
    local.yaml_new_doc,
    join(local.yaml_new_doc, data.null_data_source.master_instance_groups.*.outputs.rendered),
    local.yaml_new_doc,
    join(local.yaml_new_doc, data.null_data_source.instance_groups.*.outputs.rendered),
    local.yaml_new_doc,
    data.null_data_source.bastion_instance_group.outputs.rendered
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

# Workaround for https://github.com/terraform-providers/terraform-provider-aws/issues/8242
resource "aws_iam_user" "kops" {
  count = var.external_account ? 1 : 0
  name  = module.kops_label.id
  tags  = module.kops_label.tags
  path  = "/system/"
}

data "aws_iam_policy_document" "kops" {
  count = var.external_account ? 1 : 0

  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = [
      "AmazonRoute53FullAccess",
      "AmazonEC2FullAccess",
      "AmazonVPCFullAccess",
      "AmazonS3FullAccess",
      "IAMFullAccess",
    ]
  }
}

resource "aws_iam_user_policy" "kops" {
  count  = var.external_account ? 1 : 0
  name   = module.kops_label.id
  user   = join("", aws_iam_user.kops.*.name)
  policy = join("", data.aws_iam_policy_document.kops.*.json)
}

resource "aws_iam_access_key" "kops" {
  count = var.external_account ? 1 : 0
  user  = join("", aws_iam_user.kops.*.name)
}

resource "null_resource" "kops_update_cluster" {
  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = <<EOF
      echo "${local.kops_cluster}" | kops replace --force -f -;
      kops create secret sshpublickey kops -i ${module.ssh_key_pair.public_key_filename};
      kops update cluster --yes
EOF
  }

  triggers = {
    hash = md5(local.kops_cluster)
  }
}

resource "null_resource" "export_kubecfg" {
  depends_on = [null_resource.kops_update_cluster]

  provisioner "local-exec" {
    command     = "kops export kubecfg"
    environment = local.kops_env_config
  }

  # Always trigger export
  triggers = {
    hash = uuid()
  }
}

resource "null_resource" "kops_delete_cluster" {
  provisioner "local-exec" {
    when        = "destroy"
    command     = "kops delete cluster --yes"
    environment = local.kops_env_config
  }
}
