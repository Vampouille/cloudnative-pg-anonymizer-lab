resource "kubernetes_namespace" "prometheus" {

  metadata {
    annotations = {
    "scheduler.alpha.kubernetes.io/node-selector" = "k8s.scaleway.com/project-env=infra"
    }

    name = "kube-prometheus-stack"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "70.7.0"

  namespace          = kubernetes_namespace.prometheus.metadata[0].name
  #disable_webhooks  = true
  #disable_crd_hooks = true
  #skip_crds         = true
  dependency_update  = true
  create_namespace   = true
  #timeout           = 10800
  atomic             = true
  upgrade_install    = true
  force_update       = true

  values = [file("${path.module}/values-kube-prometheus-stack.yaml")]
}