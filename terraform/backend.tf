# K3s Production Cluster - Terraform Backend Configuration
# Uses local filesystem backend for state persistence

terraform {
  backend "local" {
    path = "/var/lib/libvirt/terraform/k3s-production-cluster/terraform.tfstate"
  }
}
