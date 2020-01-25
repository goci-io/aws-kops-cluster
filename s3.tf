module "s3_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.kops_label.context
  attributes = ["state"]
}

locals {
  default_s3_actions   = ["s3:Get*", "s3:List*"]
  default_s3_resources = [
    "arn:aws:s3:::${aws_s3_bucket.kops_state.id}",
    "arn:aws:s3:::${aws_s3_bucket.kops_state.id}/${local.cluster_dns}/*",
  ]

  application_access_log_account = {
    eu-central-1 = "054676820928",
    eu-west-2 = "652711504416",
    us-east-1 = "127311923021",
    us-west-2 = "797873946194",
    ap-northeast-2 = "600734575887",
    ap-southeast-1 = "114774131450",
    ap-east-1 = "754344448648",
    # TODO: complete list
  }

  api_log_s3_policies = [
    {
      readonly  = false
      resources = [aws_s3_bucket.kops_state.arn]
      actions   = ["s3:GetBucketAcl"]
      principals = [{
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }]
    },
    {
      readonly  = false
      resources = [format("%s/%s/*", aws_s3_bucket.kops_state.arn, local.api_log_prefix)]
      actions   = ["s3:PutObject"]
      principals = [{
        type        = "Service"
        identifiers = ["delivery.logs.amazonaws.com"]
      }]
    },
    {
      readonly  = false
      resources = [format("%s/%s/*", aws_s3_bucket.kops_state.arn, local.api_log_prefix)]
      actions   = ["s3:PutObject"]
      principals = [{
        type        = "AWS"
        identifiers = [format("arn:aws:iam::%s:root", local.application_access_log_account[local.aws_region])]
      }]
    }
  ]

  required_s3_policies = concat([], local.create_additional_loadbalancer ? local.api_log_s3_policies : [])
  custom_s3_policies   = concat(var.custom_s3_policies, local.required_s3_policies)
}

resource "aws_s3_bucket" "kops_state" {
  bucket        = module.s3_label.id
  tags          = module.s3_label.tags
  region        = local.aws_region
  acl           = "private"
  force_destroy = false

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = local.cluster_dns

    noncurrent_version_expiration {
      days = 90
    }
  }

  lifecycle_rule {
    enabled = true
    prefix  = local.api_log_prefix

    expiration {
      days = 120
    }
  }
}

data "aws_iam_policy_document" "custom_s3" {
  count = length(local.custom_s3_policies) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = local.custom_s3_policies

    content {
      effect    = "Allow"
      resources = lookup(statement.value, "resources", local.default_s3_resources)
      actions   = lookup(statement.value, "readonly", true) ? local.default_s3_actions : lookup(statement.value, "actions", ["*"])

      dynamic "principals" {
        for_each = lookup(statement.value, "principals", [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }
    }
  }
}

resource "aws_s3_bucket_policy" "current" {
  count  = length(var.custom_s3_policies) > 0 ? 1 : 0
  bucket = aws_s3_bucket.kops_state.id
  policy = join("", data.aws_iam_policy_document.custom_s3.*.json)
}

resource "aws_s3_bucket_public_access_block" "block" {
  depends_on              = [aws_s3_bucket_policy.current]
  bucket                  = aws_s3_bucket.kops_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
