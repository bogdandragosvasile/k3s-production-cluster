# K3s Production Cluster - Outputs
# Inspired by https://github.com/bogdandragosvasile/k8s-libvirt-cluster

output "cluster_name" {
  description = "Name of the K3s cluster"
  value       = var.cluster_name
}

output "network_name" {
  description = "Name of the K3s network"
  value       = libvirt_network.k3s_network.name
}

output "network_cidr" {
  description = "CIDR block of the K3s network"
  value       = libvirt_network.k3s_network.addresses[0]
}

output "pool_name" {
  description = "Name of the K3s storage pool"
  value       = libvirt_pool.k3s_pool.name
}

# Master nodes
output "master_nodes" {
  description = "Master node information"
  value = {
    for i in range(var.master_count) : "k3s-${var.cluster_name}-master-${i + 1}" => {
      name    = libvirt_domain.k3s_master[i].name
      ip      = cidrhost(var.network_cidr, var.master_ip_offset + i)
      memory  = var.master_memory
      cpu     = var.master_cpu
      role    = "master"
    }
  }
}

# Worker nodes
output "worker_nodes" {
  description = "Worker node information"
  value = {
    for i in range(var.worker_count) : "k3s-${var.cluster_name}-worker-${i + 1}" => {
      name    = libvirt_domain.k3s_worker[i].name
      ip      = cidrhost(var.network_cidr, var.worker_ip_offset + i)
      memory  = var.worker_memory
      cpu     = var.worker_cpu
      role    = "worker"
    }
  }
}

# Load balancer nodes
output "lb_nodes" {
  description = "Load balancer node information"
  value = {
    for i in range(var.lb_count) : "k3s-${var.cluster_name}-lb-${i + 1}" => {
      name    = libvirt_domain.k3s_lb[i].name
      ip      = cidrhost(var.network_cidr, var.lb_ip_offset + i)
      memory  = var.lb_memory
      cpu     = var.lb_cpu
      role    = "loadbalancer"
    }
  }
}

# Cluster endpoints
output "api_server_endpoint" {
  description = "K3s API server endpoint"
  value       = "https://${cidrhost(var.network_cidr, var.lb_ip_offset)}:6443"
}

output "k3s_token" {
  description = "K3s cluster token"
  value       = var.k3s_token != "" ? var.k3s_token : "Generated during cluster setup"
  sensitive   = true
}

# SSH access information
output "ssh_access" {
  description = "SSH access information"
  value = {
    user        = "ubuntu"
    key_file    = "~/.ssh/k3s-cluster"
    master_ips  = [for i in range(var.master_count) : cidrhost(var.network_cidr, var.master_ip_offset + i)]
    worker_ips  = [for i in range(var.worker_count) : cidrhost(var.network_cidr, var.worker_ip_offset + i)]
    lb_ips      = [for i in range(var.lb_count) : cidrhost(var.network_cidr, var.lb_ip_offset + i)]
  }
}

# Ansible inventory
output "inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    cluster_name = var.cluster_name
    network_cidr = var.network_cidr
    master_count = var.master_count
    master_ip_offset = var.master_ip_offset
    worker_count = var.worker_count
    worker_ip_offset = var.worker_ip_offset
    storage_count = var.storage_count
    storage_ip_offset = var.storage_ip_offset
    lb_count = var.lb_count
    lb_ip_offset = var.lb_ip_offset
    gpu_count = var.gpu_count
    gpu_ip_offset = var.gpu_ip_offset
  })
}

# Cluster information
output "cluster_info" {
  description = "Cluster information summary"
  value = {
    total_nodes = var.master_count + var.worker_count + var.lb_count
    masters     = var.master_count
    workers     = var.worker_count
    load_balancers = var.lb_count
    k3s_version = var.k3s_version
    longhorn_version = var.longhorn_version
    metallb_version = var.metallb_version
  }
}
