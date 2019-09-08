
resource "kubernetes_config_map" "aws_iam_authenticator" {
  metadata {
    name      = "aws-iam-authenticator"
    namespace = "kube-system"

    labels = {
      k8s-app                        = "aws-iam-authenticator"
      app.kubernetes.io / name       = "aws-iam-authenticator"
      app.kubernetes.io / managed-by = "terraform/kops"
    }
  }

  data = {
    config.yaml = templatefile("${path.module}/templates/config.yaml", {
      cluster_name   = local.cluster_name
      aws_account_id = local.aws_account_id
    })
  }
}

resource "null_resource" "pdb" {
  triggers = {
    key = "${md5(file("${path.module}/templates/poddisruptionbudget.yaml"))}"
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/templates/poddisruptionbudget.yaml"
  }
}

resource "null_resource" "remove_pdb" {
  depends_on = ["null_resource.pdb"]

  triggers = {
    key = "${md5(file("${path.module}/templates/poddisruptionbudget.yaml"))}"
  }

  provisioner "local-exec" {
    when    = "destroy"
    command = "kubectl delete -f ${path.module}/templates/poddisruptionbudget.yaml --ignore-not-found"
  }
}
