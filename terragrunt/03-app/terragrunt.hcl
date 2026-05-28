dependency "kapsule" {
  config_path = "../01-kapsule/"
}

dependency "middleware" {
  config_path  = "../02-middleware/"
  skip_outputs = true
}

inputs = {
  kubeconfig = dependency.kapsule.outputs.kubeconfig
  ingress_lb = dependency.kapsule.outputs.ingress_lb
}
