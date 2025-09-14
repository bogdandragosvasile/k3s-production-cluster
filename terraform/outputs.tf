# K3s Production Cluster - Outputs
# Simplified version for pipeline

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
