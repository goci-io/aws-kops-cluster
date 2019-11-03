module "s3_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.kops_label.context
  attributes = ["state"]
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

    noncurrent_version_expiration {
      days = 360
    }
  }
}

data "aws_iam_policy_document" "custom_s3" {
  count = length(var.custom_s3_policies) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.custom_s3_policies

    content {
      effect    = "Allow"
      resources = lookup(statement.value, "resources", ["arn:aws:s3:::${aws_s3_bucket.kops_state.id}/*"])
      actions   = lookup(statement.value, "readonly", true) ? ["s3:Get*"] : lookup(statement.value, "actions", ["*"])

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
  bucket                  = aws_s3_bucket.kops_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
