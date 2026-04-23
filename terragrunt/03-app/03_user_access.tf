resource "random_password" "token" {
  count = local.variables.users

  length  = 8
  special = false
  upper   = false
  lower   = true
  numeric = false
}

locals {
  users = [for count in range(local.variables.users):
    {
      username = "user${count + 1}",
      password = random_password.token[count].result
    }
  ]
}


resource "helm_release" "this" {
  name       = "users"
  chart      = "../../charts/users"

  namespace = "users"
  #disable_webhooks   = true
  #disable_crd_hooks = true
  #skip_crds         = true
  dependency_update = true
  create_namespace = true
  #timeout           = 10800
  atomic          = true
  upgrade_install = true
  force_update    = true

  values = [yamlencode({
    users = local.users
    ingress = {
      host    = local.variables.workshop_domain
      enabled = true
    }
  })]

}

resource "local_file" "users_values" {
  filename = "${path.module}/../../charts/users/values-test.yaml"
  content = yamlencode({
    users = local.users
    ingress = {
      host    = local.variables.workshop_domain
      enabled = true
    }
  })
}

#TODO: middleware rate limit for token resolution

data "http" "pagedjs" {
  url = "https://unpkg.com/pagedjs/dist/paged.polyfill.js"
}

resource "local_file" "access_cards" {
  filename = "${path.module}/../../cards/cards.html"
  content = templatefile("${path.module}/templates/cards.html.tpl", {
    users  = local.users
    domain = local.variables.workshop_domain
    css    = file("${path.module}/../../cards/styles.css")
    pagedjs = data.http.pagedjs.response_body
  })
}
