output "ingress_lb" {
  description = "Public LB for enduser ingress trafic"
  value = {
    id         = scaleway_lb.this.id
    ip         = scaleway_lb_ip.this.ip_address
    private_ip = split("/", scaleway_ipam_ip.this.address)[0]
  }
}

output "egress_gateway" {
  description = "Egress gateway informations"
  value = {
    id         = scaleway_vpc_public_gateway.this.id
    ip         = scaleway_vpc_public_gateway_ip.this.address
    private_ip = split("/", scaleway_ipam_ip.k8s_outgoing.address)[0]
  }
}

output "kubeconfig" {
  value     = scaleway_k8s_cluster.this.kubeconfig[0]
  sensitive = true
}

output "cluster" {
  description = "Cluster infos"
  value = {
    id = scaleway_k8s_cluster.this.id
  }
}

output "private_network_id" {
  value = scaleway_vpc_private_network.this.id
}
