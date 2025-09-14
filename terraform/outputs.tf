# K3s Production Cluster - Outputs
# Minimal version for pipeline

# Ansible inventory
output "inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    cluster_name = var.cluster_name
    network_cidr = "192.168.122.0/24"
    master_count = 3
    master_ip_offset = 10
    worker_count = 6
    worker_ip_offset = 20
    storage_count = 2
    storage_ip_offset = 40
    lb_count = 2
    lb_ip_offset = 30
    gpu_count = 1
    gpu_ip_offset = 50
  })
}
