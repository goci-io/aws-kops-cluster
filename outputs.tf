
output "cluster_name" {
  value = local.cluster_dns
}

output "kops_state_store" {
  value = "s3://${aws_s3_bucket.kops_state.id}"
}
