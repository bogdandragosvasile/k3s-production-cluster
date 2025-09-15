# K3s Production Cluster - Outputs

# Ansible inventory
output "inventory" {
  description = "Ansible inventory in YAML format"
  value = templatefile("${path.module}/templates/inventory.tpl", {
    master1_ip = "192.168.122.11"
    master2_ip = "192.168.122.12"
    master3_ip = "192.168.122.13"
    worker1_ip = "192.168.122.21"
    worker2_ip = "192.168.122.22"
    worker3_ip = "192.168.122.23"
    storage1_ip = "192.168.122.31"
    storage2_ip = "192.168.122.32"
    lb1_ip = "192.168.122.41"
    lb2_ip = "192.168.122.42"
    ssh_public_key = "~/.ssh/id_rsa"
  })
}
