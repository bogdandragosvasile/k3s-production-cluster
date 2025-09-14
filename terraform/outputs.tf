# K3s Production Cluster - Terraform Outputs

output "vm_ips" {
  description = "IP addresses of all VMs"
  value = merge(
    { for vm in local.masters : vm.name => vm.ip },
    { for vm in local.workers : vm.name => vm.ip },
    { for vm in local.storage : vm.name => vm.ip },
    { for vm in local.load_balancers : vm.name => vm.ip }
  )
}

output "master_nodes" {
  description = "Master node information"
  value = [
    for i in range(length(local.masters)) : {
      name = local.masters[i].name
      ip   = local.masters[i].ip
      memory = local.masters[i].memory
      vcpu = local.masters[i].vcpu
    }
  ]
}

output "worker_nodes" {
  description = "Worker node information"
  value = [
    for i in range(length(local.workers)) : {
      name = local.workers[i].name
      ip   = local.workers[i].ip
      memory = local.workers[i].memory
      vcpu = local.workers[i].vcpu
    }
  ]
}

output "storage_nodes" {
  description = "Storage node information"
  value = [
    for i in range(length(local.storage)) : {
      name = local.storage[i].name
      ip   = local.storage[i].ip
      memory = local.storage[i].memory
      vcpu = local.storage[i].vcpu
    }
  ]
}

output "load_balancer_nodes" {
  description = "Load balancer node information"
  value = [
    for i in range(length(local.load_balancers)) : {
      name = local.load_balancers[i].name
      ip   = local.load_balancers[i].ip
      memory = local.load_balancers[i].memory
      vcpu = local.load_balancers[i].vcpu
    }
  ]
}

output "cluster_info" {
  description = "Cluster summary information"
  value = {
    cluster_name = var.cluster_name
    total_nodes = length(local.masters) + length(local.workers) + length(local.storage) + length(local.load_balancers)
    masters = length(local.masters)
    workers = length(local.workers)
    storage = length(local.storage)
    load_balancers = length(local.load_balancers)
    network = "default"
    gateway = var.gateway
    dns = var.dns
  }
}
# Ansible inventory
output "inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    master_nodes = {
      for i in range(var.master_count) : "k3s-${var.cluster_name}-master-${i + 1}" => {
        ip = cidrhost(var.network_cidr, var.master_ip_offset + i)
      }
    }
    worker_nodes = {
      for i in range(var.worker_count) : "k3s-${var.cluster_name}-worker-${i + 1}" => {
        ip = cidrhost(var.network_cidr, var.worker_ip_offset + i)
      }
    }
    storage_nodes = {
      for i in range(var.storage_count) : "k3s-${var.cluster_name}-storage-${i + 1}" => {
        ip = cidrhost(var.network_cidr, var.storage_ip_offset + i)
      }
    }
    load_balancer_nodes = {
      for i in range(var.lb_count) : "k3s-${var.cluster_name}-lb-${i + 1}" => {
        ip = cidrhost(var.network_cidr, var.lb_ip_offset + i)
      }
    }
  })
}
