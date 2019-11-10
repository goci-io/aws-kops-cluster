
resource "tls_private_key" "kubernetes" {
  algorithm = "RSA"
}

resource "tls_cert_request" "kubernetes" {
  key_algorithm   = "RSA"
  private_key_pem = tls_private_key.kubernetes.private_key_pem
  ip_addresses    = ["127.0.0.1"]
  dns_names       = [
    format("api.%s", local.cluster_dns), 
    "kubernetes", 
    "kubernetes.default", 
    "kubernetes.default.svc", 
    "kubernetes.default.svc.cluster", 
    "kubernetes.default.svc.cluster.local",
  ]

  subject {
    common_name  = "kubernetes"
    organization = "system:nodes"
  }
}

resource "tls_locally_signed_cert" "kubernetes" {
  ca_key_algorithm      = "RSA"
  cert_request_pem      = tls_cert_request.kubernetes.cert_request_pem
  ca_private_key_pem    = local.certificate_ca_key_pem
  ca_cert_pem           = local.certificate_ca_pem
  validity_period_hours = 8640
  is_ca_certificate     = true

  # Allowed uses for kubernetes certificate issuer
  allowed_uses = [
    "crl_signing", 
    "cert_signing",
  ]
}

resource "local_file" "ca_key" {
  count             = local.custom_certificate_enabled ? 1 : 0
  filename          = "${var.secrets_path}/pki/key.pem"
  sensitive_content = tls_private_key.kubernetes.private_key_pem
}

resource "local_file" "ca_cert" {
  count             = local.custom_certificate_enabled ? 1 : 0
  filename          = "${var.secrets_path}/pki/cert.pem"
  sensitive_content = tls_locally_signed_cert.kubernetes.cert_pem
}

resource "null_resource" "custom_ca" {
  count      = local.custom_certificate_enabled ? 1 : 0
  depends_on = [null_resource.replace_cluster]

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "kops create secret keypair ca --cert ${join("", local_file.ca_cert.*.filename)} --key ${join("", local_file.ca_key.*.filename)}"
  }

  triggers = {
    hash = md5(join("", local_file.ca_cert.*.sensitive_content))
  }
}

resource "null_resource" "delete_ca" {
  count = local.custom_certificate_enabled ? 1 : 0

  provisioner "local-exec" {
    environment = local.kops_env_config
    command     = "kops delete secret keypair ca || exit 0"
    when        = "destroy"
  }
}
