resource "kubernetes_namespace" "dashboard" {

  metadata {
    annotations = {
    "scheduler.alpha.kubernetes.io/node-selector" = "k8s.scaleway.com/project-env=infra"
    }

    name = "kubernetes-dashboard"
  }
}

resource "helm_release" "dashboard" {
  name             = "headlamp"
  repository       = "https://kubernetes-sigs.github.io/headlamp/"
  chart            = "headlamp"

  namespace        = kubernetes_namespace.dashboard.metadata[0].name
  create_namespace = true
  dependency_update = true
  atomic           = true
  upgrade_install  = true

  values = [templatefile("${path.module}/values-headlamp.yaml", {
    domain = local.variables.workshop_domain
  })]
}

# ── htpasswd entries (bcrypt) for all participants ────────────────────────────
locals {
  dashboard_htpasswd = join("\n", [
    for u in local.users : "${u.username}:${bcrypt(u.password)}"
  ])
}

# ── Secret consumed by the Traefik basicAuth middleware ───────────────────────
resource "kubernetes_secret" "dashboard_basicauth" {
  metadata {
    name      = "dashboard-basicauth"
    namespace = kubernetes_namespace.dashboard.metadata[0].name
  }
  data = {
    users = local.dashboard_htpasswd
  }
  depends_on = [helm_release.dashboard]
}

resource "kubernetes_manifest" "dashboard_middleware_auth" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "dashboard-basicauth"
      namespace = kubernetes_namespace.dashboard.metadata[0].name
    }
    spec = {
      basicAuth = {
        secret = kubernetes_secret.dashboard_basicauth.metadata[0].name
      }
    }
  }
}