data "aws_route53_zone" "workshop" {
  name = "${local.variables.workshop_domain}."
}

# One A record per user, taken from the "url" column of the users CSV
resource "aws_route53_record" "users" {
  for_each = { for u in local.users : u.user => u }

  zone_id = data.aws_route53_zone.workshop.zone_id
  name    = each.value.host
  type    = "A"
  ttl     = 60
  records = [var.ingress_lb.ip]

  lifecycle {
    precondition {
      condition     = endswith(each.value.host, ".${local.variables.workshop_domain}")
      error_message = "User ${each.key}: url \"${each.value.host}\" is not in the workshop domain \"${local.variables.workshop_domain}\" (expected a bare hostname like ${each.key}.${local.variables.workshop_domain}, without scheme or path)."
    }
  }
}

# Kubernetes Dashboard
resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.workshop.zone_id
  name    = "dashboard.${local.variables.workshop_domain}"
  type    = "A"
  ttl     = 60
  records = [var.ingress_lb.ip]
}
