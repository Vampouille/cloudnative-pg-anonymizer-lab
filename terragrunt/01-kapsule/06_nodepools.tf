# Kubernetes node pools
resource "scaleway_instance_placement_group" "this" {
  for_each = local.variables.cluster.pools

  name = each.key
  tags = each.value.tags
}

resource "scaleway_k8s_pool" "this" {
  for_each = local.variables.cluster.pools

  name                   = each.key
  node_type              = each.value.node_type
  size                   = each.value.size
  min_size               = each.value.size
  cluster_id             = scaleway_k8s_cluster.this.id
  autohealing            = true
  root_volume_type       = each.value.root_volume_type
  root_volume_size_in_gb = each.value.root_volume_size_in_gb

  container_runtime   = "containerd"
  placement_group_id  = scaleway_instance_placement_group.this[each.key].id
  wait_for_pool_ready = true
  public_ip_disabled  = true # full isolation
  tags                = each.value.tags

  lifecycle {
    ignore_changes = [
      wait_for_pool_ready,
    ]
  }

  depends_on = [
    scaleway_vpc_gateway_network.this # public_ip_disabled=true require a public gateway to be attached to the private network
  ]
}
