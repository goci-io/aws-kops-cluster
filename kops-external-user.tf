
# Workaround for https://github.com/terraform-providers/terraform-provider-aws/issues/8242

locals {
  kops_policies = [
    "arn:aws:iam::aws:policy/AmazonRoute53FullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess",
  ]
}

data "aws_iam_policy_document" "kops" {
  statement {
    effect    = "Allow"
    actions   = []
    resources = []
  }
}

resource "aws_iam_user" "kops" {
  count = var.external_account ? 1 : 0
  name  = module.kops_label.id
  tags  = module.kops_label.tags
  path  = "/system/"
}

resource "aws_iam_user_policy_attachment" "permissions" {
  count      = var.external_account ? length(local.kops_policies) : 0
  user       = join("", aws_iam_user.kops.*.name)
  policy_arn = local.kops_policies[count.index]
}

resource "aws_iam_access_key" "kops" {
  count      = var.external_account ? 1 : 0
  user       = join("", aws_iam_user.kops.*.name)
}

# Wait for IAM to propagate new user
resource "null_resource" "wait_for_iam" {
  count      = var.external_account ? 1 : 0

  provisioner "local-exec" {
    command = "sleep 30"
  }

  triggers = {
    user = join("", aws_iam_access_key.kops.*.id)
  }
}
