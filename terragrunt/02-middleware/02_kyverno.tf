resource "helm_release" "kyverno" {
  name       = "kyverno"
  repository = "https://kyverno.github.io/kyverno/"
  chart      = "kyverno"
  version    = "3.7.1"

  namespace = "kyverno"
  #disable_webhooks   = true
  #disable_crd_hooks = true
  #skip_crds         = true
  dependency_update = true
  create_namespace = true
  #timeout           = 10800
  atomic          = true
  upgrade_install = true
  force_update    = true

  values = [file("${path.module}/values-kyverno.yaml")]
}
