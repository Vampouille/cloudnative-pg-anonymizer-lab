resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.17.2"

  namespace        = "cert-manager"
  dependency_update = true
  create_namespace = true
  atomic           = true
  upgrade_install  = true
  force_update     = true

  values = [file("${path.module}/values-cert-manager.yaml")]
}