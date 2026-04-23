resource "scaleway_vpc" "this" {
  name           = local.variables.name
  region         = local.variables.region
  enable_routing = true
}

resource "scaleway_vpc_private_network" "this" {
  name   = local.variables.name
  vpc_id = scaleway_vpc.this.id

  ipv4_subnet {
    subnet = local.variables.network_mask
  }
}
