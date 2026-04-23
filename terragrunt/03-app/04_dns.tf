data "aws_route53_zone" "workshop" {
  name = "${local.variables.workshop_domain}."
}

# One A record per user: user1.campto.camp, user2.campto.camp, ...
resource "aws_route53_record" "users" {
  for_each = { for u in local.users : u.username => u }

  zone_id = data.aws_route53_zone.workshop.zone_id
  name    = "${each.key}.${local.variables.workshop_domain}"
  type    = "A"
  ttl     = 60
  records = [var.ingress_lb.ip]
}

# Kubernetes Dashboard
resource "aws_route53_record" "dashboard" {
  zone_id = data.aws_route53_zone.workshop.zone_id
  name    = "dashboard.${local.variables.workshop_domain}"
  type    = "A"
  ttl     = 60
  records = [var.ingress_lb.ip]
}
