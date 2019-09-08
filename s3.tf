module "s3_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.label.context
  attributes = ["kops", "state"]
}

resource "aws_s3_bucket" "kops_state" {
  bucket        = module.s3_label.id
  tags          = module.s3_label.tags
  region        = var.aws_region
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
