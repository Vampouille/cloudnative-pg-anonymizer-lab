provider "aws" {
  profile = "c2c-is-training"
  region = "eu-west-1"
}

variable "kubeconfig" {
  description = "Cluster credentials"
  type = object({
    config_file            = string
    host                   = string
    cluster_ca_certificate = string
    token                  = string
  })
}

variable "ingress_lb" {
  description = "Public ingress load balancer info from 01-kapsule"
  type = object({
    id         = string
    ip         = string
    private_ip = string
  })
}

provider "kubernetes" {
  host                   = var.kubeconfig.host
  token                  = var.kubeconfig.token
  cluster_ca_certificate = base64decode(var.kubeconfig.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = var.kubeconfig.host
    token                  = var.kubeconfig.token
    cluster_ca_certificate = base64decode(var.kubeconfig.cluster_ca_certificate)
  }
}
