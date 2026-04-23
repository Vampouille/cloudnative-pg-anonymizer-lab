resource "scaleway_k8s_cluster" "this" {
  name                        = local.variables.name
  description                 = local.variables.description
  cni                         = "cilium"
  type                        = local.variables.cluster.type
  version                     = local.variables.cluster.version
  private_network_id          = scaleway_vpc_private_network.this.id
  apiserver_cert_sans         = ["master.api.${local.variables.name}"]
  delete_additional_resources = true
  admission_plugins           = ["PodNodeSelector"]

  autoscaler_config {
    disable_scale_down = true
  }

  auto_upgrade {
    enable                        = true
    maintenance_window_start_hour = 0
    maintenance_window_day        = "sunday"
  }
}

resource "local_file" "kubeconfig_admin" {
  filename        = "${path.module}/../kubeconfig-admin"
  file_permission = "0600"
  content         = scaleway_k8s_cluster.this.kubeconfig[0].config_file
}
