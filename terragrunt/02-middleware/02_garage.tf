resource "kubernetes_namespace" "garage" {

  metadata {
    annotations = {
    "scheduler.alpha.kubernetes.io/node-selector" = "k8s.scaleway.com/project-env=infra"
    }

    name = "garage"
  }
}

resource "helm_release" "garage" {
  name       = "garage"
  chart      = "../../charts/garage/script/helm/garage"

  namespace = kubernetes_namespace.garage.metadata[0].name
  #disable_webhooks   = true
  #disable_crd_hooks = true
  #skip_crds         = true
  dependency_update = true
  create_namespace = true
  #timeout           = 10800
  atomic          = true
  upgrade_install = true
  force_update    = true

  values = [file("${path.module}/values-garage.yaml")]
}
