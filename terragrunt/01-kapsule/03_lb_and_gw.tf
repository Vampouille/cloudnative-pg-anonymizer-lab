##
# Main LB
##

# public IP
resource "scaleway_lb_ip" "this" {
  zone = local.variables.zone
}
# Private IP
resource "scaleway_ipam_ip" "this" {
  address = cidrhost(local.variables.network_mask, 2) # x.x.x.2
  source {
    private_network_id = scaleway_vpc_private_network.this.id
  }
}
resource "scaleway_lb" "this" {
  name        = local.variables.name
  description = "This load balancer receive the traffic for client workload"
  ip_ids      = [scaleway_lb_ip.this.id]
  zone        = scaleway_lb_ip.this.zone
  type        = local.variables.cluster.lb_type

  private_network {
    private_network_id = scaleway_vpc_private_network.this.id
    ipam_ids           = [scaleway_ipam_ip.this.id]
  }
}

##
# Internet Gateway
##

# Public IP
resource "scaleway_vpc_public_gateway_ip" "this" {
  zone = local.variables.zone
}
# Private IP
resource "scaleway_ipam_ip" "k8s_outgoing" {
  address = cidrhost(local.variables.network_mask, 3) # x.x.x.3
  source {
    private_network_id = scaleway_vpc_private_network.this.id
  }
}

resource "scaleway_vpc_public_gateway" "this" {
  name            = local.variables.name
  ip_id           = scaleway_vpc_public_gateway_ip.this.id
  zone            = scaleway_vpc_public_gateway_ip.this.zone
  type            = local.variables.cluster.gateway_type
}

resource "scaleway_vpc_gateway_network" "this" {
  gateway_id         = scaleway_vpc_public_gateway.this.id
  private_network_id = scaleway_vpc_private_network.this.id
  enable_masquerade  = true
  ipam_config {
    push_default_route = true
    ipam_ip_id         = scaleway_ipam_ip.k8s_outgoing.id
  }
  zone = scaleway_vpc_public_gateway_ip.this.zone
}
