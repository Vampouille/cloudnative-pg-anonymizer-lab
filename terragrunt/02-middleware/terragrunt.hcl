dependency "kapsule" {
  config_path = "../01-kapsule/"
}

inputs = {
  kubeconfig = dependency.kapsule.outputs.kubeconfig
  ingress_lb = dependency.kapsule.outputs.ingress_lb
}
