
output "external_user_key" {
  value = join("", aws_iam_access_key.kops.*.id)
}

output "external_user_secret" {
  value     = join("", aws_iam_access_key.kops.*.secret)
  sensitive = true
}

output "cluster_name" {
  value = local.cluster_dns
}

output "kops_state_store" {
  value = "s3://${aws_s3_bucket.kops_state.id}"
}
