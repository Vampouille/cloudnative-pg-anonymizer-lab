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


#resource "helm_release" "example" {
#  count = local.variables.user_tokens
#
#  name       = "my-local-chart"
#  chart      = "../../charts/user_access"
#}

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
