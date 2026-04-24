dependency "kapsule" {
  config_path = "../01-kapsule/"
}

dependency "middleware" {
  config_path  = "../02-middleware/"
  skip_outputs = true
}

terraform {
  after_hook "setup_users" {
    commands = ["apply"]
    execute  = ["${get_repo_root()}/scripts/setup-users.sh"]
    run_on_error = false
  }
}

inputs = {
  kubeconfig = dependency.kapsule.outputs.kubeconfig
  ingress_lb = dependency.kapsule.outputs.ingress_lb
}
