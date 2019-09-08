locals {
  iam_auth_pdb_hash = md5(file("${path.module}/templates/iam-auth-pdb.yaml"))
}

module "role_label" {
  source     = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context    = module.label.context
  name       = "k8s"
}

resource "kubernetes_config_map" "aws_iam_authenticator" {
  depends_on = [null_resource.cluster]

  metadata {
    name      = "aws-iam-authenticator"
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name"       = "aws-iam-authenticator"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  data = {
    "config.yaml" = templatefile("${path.module}/templates/iam-auth.yaml", {
      cluster_name   = local.cluster_name
      aws_account_id = local.aws_account_id
      ci_role        = format("%s%sci", module.role_label.id, var.delimiter)
      admin_role     = format("%s%sadmin", module.role_label.id, var.delimiter)
      readonly_role  = format("%s%sreadonly", module.role_label.id, var.delimiter)
      power_role     = format("%s%spower", module.role_label.id, var.delimiter)
    })
  }
}

resource "null_resource" "pdb" {
  triggers = {
    key = "${local.iam_auth_pdb_hash}"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/templates/iam-auth-pdb.yaml"
  }
}

resource "null_resource" "remove_pdb" {
  depends_on = ["null_resource.pdb"]

  triggers = {
    key = "${local.iam_auth_pdb_hash}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete -f ${path.module}/templates/iam-auth-pdb.yaml --ignore-not-found"
  }
}
