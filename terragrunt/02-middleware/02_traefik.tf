resource "kubernetes_namespace" "traefik" {

  metadata {
    annotations = {
    "scheduler.alpha.kubernetes.io/node-selector" = "k8s.scaleway.com/project-env=infra"
    }

    name = "traefik"
  }
}

variable "ingress_lb" {
  description = "Load balancer for end users trafic"
  type = object({
    id  = string
    ip  = string
  })
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = "39.0.8"

  namespace          = kubernetes_namespace.traefik.metadata[0].name
  #disable_webhooks  = true
  #disable_crd_hooks = true
  #skip_crds         = true
  dependency_update  = true
  create_namespace   = true
  #timeout           = 10800
  atomic             = true
  upgrade_install    = true
  force_update       = true

  values = [templatefile("${path.module}/values-traefik.yaml", {
    lb_id = var.ingress_lb.id
  })]
}
