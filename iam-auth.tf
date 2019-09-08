locals {
  iam_auth_pdb_hash = md5(file("${path.module}/templates/iam-auth-pdb.yaml"))
}

module "ci_role_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context = module.label.context
  name    = "ci"
}

module "admin_role_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context = module.label.context
  name    = "admin"
}

module "readonly_role_label" {
  source  = "git::https://github.com/cloudposse/terraform-null-label.git?ref=tags/0.15.0"
  context = module.label.context
  name    = "readonly"
}

resource "kubernetes_config_map" "aws_iam_authenticator" {
  depends_on = [null_resource.export_kubecfg]

  metadata {
    name      = "aws-iam-authenticator"
    namespace = "kube-system"

    labels = {
      app                            = "aws-iam-authenticator"
      "app.kubernetes.io/name"       = "aws-iam-authenticator"
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  data = {
    "config.yaml" = templatefile("${path.module}/templates/iam-auth.yaml", {
      cluster_name   = local.cluster_name
      aws_account_id = local.aws_account_id
      ci_role        = module.ci_role_label.id
      admin_role     = module.admin_role_label.id
      readonly_role  = module.readonly_role_label.id
    })
  }
}

resource "null_resource" "pdb" {
  depends_on = [null_resource.export_kubecfg]

  triggers = {
    key = "${local.iam_auth_pdb_hash}"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/templates/iam-auth-pdb.yaml"
  }
}

resource "null_resource" "remove_pdb" {
  depends_on = [null_resource.export_kubecfg]

  triggers = {
    key = "${local.iam_auth_pdb_hash}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete -f ${path.module}/templates/iam-auth-pdb.yaml --ignore-not-found"
  }
}
