# K3s Production Cluster - Outputs
# Simple version for pipeline

# Ansible inventory
output "inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {})
}
