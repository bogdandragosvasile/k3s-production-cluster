# K3s Production Cluster Variables

variable "cluster_name" {
  description = "Name of the K3s cluster"
  type        = string
  default     = "k3s-production"
}

variable "base_image_path" {
  description = "Path to the base Ubuntu cloud image"
  type        = string
  default     = "/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
  default     = ""
}

variable "network_interface" {
  description = "Network interface name for cloud-init"
  type        = string
  default     = "ens3"
}

variable "gateway" {
  description = "Network gateway IP"
  type        = string
  default     = "192.168.122.1"
}

variable "dns" {
  description = "DNS server IP"
  type        = string
  default     = "8.8.8.8"
}