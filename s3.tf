module "s3_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.kops_label.context
  attributes = ["state"]
}

locals {
  ssh_key_path = format("%s/ssh/%s", var.secrets_path, module.kops_label.id)
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
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.kops_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "ssh_key" {
  count      = var.ssh_key_bucket == "" ? 0 : 1
  depends_on = [null_resource.kops_update_cluster]
  provider   = aws.current
  key        = "kops/ssh/admin.pem"
  bucket     = var.ssh_key_bucket
  source     = local.ssh_key_path
  etag       = filemd5(local.ssh_key_path)
}

