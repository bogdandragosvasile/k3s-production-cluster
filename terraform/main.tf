# K3s Production Cluster - Robust Terraform Configuration
# Based on patterns from k8s-libvirt-cluster repository

terraform {
  required_version = ">= 1.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.3"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# Variables are defined in variables.tf

# Auto-detect SSH public key if not provided
locals {
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/id_rsa.pub")
}

# Use existing default network (assume it exists)

# Base volume from cloud image
resource "libvirt_volume" "base" {
  name   = "ubuntu-24.04-cloudimg-amd64.img"
  source = var.base_image_path
  format = "qcow2"
  pool   = "default"
}

# Cluster configuration
locals {
  masters = [
    { name = "${var.cluster_name}-master-1", ip = "192.168.122.11", memory = 4096, vcpu = 2 },
    { name = "${var.cluster_name}-master-2", ip = "192.168.122.12", memory = 4096, vcpu = 2 },
    { name = "${var.cluster_name}-master-3", ip = "192.168.122.13", memory = 4096, vcpu = 2 }
  ]
  
  workers = [
    { name = "${var.cluster_name}-worker-1", ip = "192.168.122.21", memory = 8192, vcpu = 4 },
    { name = "${var.cluster_name}-worker-2", ip = "192.168.122.22", memory = 8192, vcpu = 4 },
    { name = "${var.cluster_name}-worker-3", ip = "192.168.122.23", memory = 8192, vcpu = 4 }
  ]
  
  storage = [
    { name = "${var.cluster_name}-storage-1", ip = "192.168.122.31", memory = 4096, vcpu = 2 },
    { name = "${var.cluster_name}-storage-2", ip = "192.168.122.32", memory = 4096, vcpu = 2 }
  ]
  
  load_balancers = [
    { name = "${var.cluster_name}-lb-1", ip = "192.168.122.41", memory = 1024, vcpu = 1 },
    { name = "${var.cluster_name}-lb-2", ip = "192.168.122.42", memory = 1024, vcpu = 1 }
  ]
}

# -------- Function to create VM sets --------

# Master nodes
resource "libvirt_volume" "masters" {
  count            = length(local.masters)
  name             = "${local.masters[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 21474836480  # 20GB
}

resource "libvirt_cloudinit_disk" "masters" {
  count          = length(local.masters)
  name           = "${local.masters[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/templates/cloud_init_user_data.tpl", {
    hostname   = local.masters[count.index].name,
    public_key = local.ssh_public_key
  })
  network_config = templatefile("${path.module}/templates/cloud_init_network_config.tpl", {
    ip      = local.masters[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns,
    interface = var.network_interface
  })
  pool           = "default"
}

resource "libvirt_domain" "masters" {
  count  = length(local.masters)
  name   = local.masters[count.index].name
  memory = local.masters[count.index].memory
  vcpu   = local.masters[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.masters[count.index].id

  disk {
    volume_id = libvirt_volume.masters[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Worker nodes
resource "libvirt_volume" "workers" {
  count            = length(local.workers)
  name             = "${local.workers[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 32212254720  # 30GB
}

resource "libvirt_cloudinit_disk" "workers" {
  count          = length(local.workers)
  name           = "${local.workers[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/templates/cloud_init_user_data.tpl", {
    hostname   = local.workers[count.index].name,
    public_key = local.ssh_public_key
  })
  network_config = templatefile("${path.module}/templates/cloud_init_network_config.tpl", {
    ip      = local.workers[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns,
    interface = var.network_interface
  })
  pool           = "default"
}

resource "libvirt_domain" "workers" {
  count  = length(local.workers)
  name   = local.workers[count.index].name
  memory = local.workers[count.index].memory
  vcpu   = local.workers[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.workers[count.index].id

  disk {
    volume_id = libvirt_volume.workers[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Storage nodes
resource "libvirt_volume" "storage" {
  count            = length(local.storage)
  name             = "${local.storage[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 21474836480  # 20GB
}

resource "libvirt_cloudinit_disk" "storage" {
  count          = length(local.storage)
  name           = "${local.storage[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/templates/cloud_init_user_data.tpl", {
    hostname   = local.storage[count.index].name,
    public_key = local.ssh_public_key
  })
  network_config = templatefile("${path.module}/templates/cloud_init_network_config.tpl", {
    ip      = local.storage[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns,
    interface = var.network_interface
  })
  pool           = "default"
}

resource "libvirt_domain" "storage" {
  count  = length(local.storage)
  name   = local.storage[count.index].name
  memory = local.storage[count.index].memory
  vcpu   = local.storage[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.storage[count.index].id

  disk {
    volume_id = libvirt_volume.storage[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Load balancer nodes
resource "libvirt_volume" "load_balancers" {
  count            = length(local.load_balancers)
  name             = "${local.load_balancers[count.index].name}.qcow2"
  base_volume_id   = libvirt_volume.base.id
  pool             = "default"
  size             = 10737418240  # 10GB
}

resource "libvirt_cloudinit_disk" "load_balancers" {
  count          = length(local.load_balancers)
  name           = "${local.load_balancers[count.index].name}-cloudinit.iso"
  user_data      = templatefile("${path.module}/templates/cloud_init_user_data.tpl", {
    hostname   = local.load_balancers[count.index].name,
    public_key = local.ssh_public_key
  })
  network_config = templatefile("${path.module}/templates/cloud_init_network_config.tpl", {
    ip      = local.load_balancers[count.index].ip,
    gateway = var.gateway,
    dns     = var.dns,
    interface = var.network_interface
  })
  pool           = "default"
}

resource "libvirt_domain" "load_balancers" {
  count  = length(local.load_balancers)
  name   = local.load_balancers[count.index].name
  memory = local.load_balancers[count.index].memory
  vcpu   = local.load_balancers[count.index].vcpu
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.load_balancers[count.index].id

  disk {
    volume_id = libvirt_volume.load_balancers[count.index].id
  }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# Inventory & Outputs
data "template_file" "inventory" {
  template = file("${path.module}/templates/inventory.tpl")

  vars = {
    master1_ip     = local.masters[0].ip
    master2_ip     = local.masters[1].ip
    master3_ip     = local.masters[2].ip
    worker1_ip     = local.workers[0].ip
    worker2_ip     = local.workers[1].ip
    worker3_ip     = local.workers[2].ip
    storage1_ip    = local.storage[0].ip
    storage2_ip    = local.storage[1].ip
    lb1_ip         = local.load_balancers[0].ip
    lb2_ip         = local.load_balancers[1].ip
  }
}

resource "local_file" "inventory" {
  content  = data.template_file.inventory.rendered
  filename = "${path.module}/../ansible/inventory.yml"
}

# Outputs are defined in outputs.tf