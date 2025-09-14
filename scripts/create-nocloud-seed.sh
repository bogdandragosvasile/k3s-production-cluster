#!/bin/bash
# Create NoCloud seed ISO for Ubuntu 24.04 LTS cloud images
# Based on Ubuntu 24.04 LTS cloud-init best practices

set -euo pipefail

# Configuration
VM_NAME="$1"
SSH_PUBLIC_KEY="$2"
NETWORK_INTERFACE="${3:-ens3}"

if [ -z "$VM_NAME" ] || [ -z "$SSH_PUBLIC_KEY" ]; then
    echo "Usage: $0 <vm-name> <ssh-public-key> [network-interface]"
    echo "Example: $0 k3s-master-1 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7...' ens3"
    exit 1
fi

# Create temporary directory for cloud-init files
TEMP_DIR="/tmp/nocloud-${VM_NAME}"
mkdir -p "$TEMP_DIR"

echo "=== Creating NoCloud seed ISO for $VM_NAME ==="

# Create user-data file
cat > "$TEMP_DIR/user-data" << EOU
#cloud-config
hostname: $VM_NAME
fqdn: $VM_NAME.k3s.local
manage_etc_hosts: true

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $SSH_PUBLIC_KEY

# Disable password authentication
ssh_pwauth: false

# Update system packages
package_update: true
package_upgrade: true

# Install essential packages
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - dnsutils
  - jq
  - unzip
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - qemu-guest-agent

# Configure timezone
timezone: UTC

# Run commands on first boot
runcmd:
  # Enable qemu-guest-agent
  - systemctl enable --now qemu-guest-agent
  
  # Update system
  - apt-get update
  - apt-get upgrade -y
  
  # Install Docker
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  
  # Install kubectl
  - curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - chmod +x kubectl
  - mv kubectl /usr/local/bin/
  
  # Install Helm
  - curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
  - echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
  - apt-get update
  - apt-get install -y helm
  
  # Configure system limits
  - echo "* soft nofile 65536" >> /etc/security/limits.conf
  - echo "* hard nofile 65536" >> /etc/security/limits.conf
  - echo "* soft nproc 65536" >> /etc/security/limits.conf
  - echo "* hard nproc 65536" >> /etc/security/limits.conf
  
  # Configure kernel parameters for Kubernetes
  - echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
  - echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  - sysctl -p
  
  # Load required kernel modules
  - echo "br_netfilter" >> /etc/modules
  - echo "overlay" >> /etc/modules
  - modprobe br_netfilter
  - modprobe overlay
  
  # Disable swap
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  
  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default | tee /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  
  # Create k3s user
  - useradd -r -s /bin/false -m -d /var/lib/rancher/k3s k3s
  
  # Set hostname
  - hostnamectl set-hostname $VM_NAME

# Final message
final_message: "K3s node $VM_NAME is ready! SSH access available for ubuntu user."
EOU

# Create meta-data file
cat > "$TEMP_DIR/meta-data" << EOM
instance-id: iid-$VM_NAME
local-hostname: $VM_NAME
EOM

# Create network-config file
cat > "$TEMP_DIR/network-config" << EON
network:
  version: 2
  ethernets:
    $NETWORK_INTERFACE:
      dhcp4: true
      dhcp6: false
EON

# Create NoCloud seed ISO
echo "Creating NoCloud seed ISO..."
genisoimage -output "/var/lib/libvirt/images/${VM_NAME}-nocloud.iso" \
  -volid cidata \
  -joliet -rock \
  "$TEMP_DIR/user-data" \
  "$TEMP_DIR/meta-data" \
  "$TEMP_DIR/network-config"

# Set proper permissions
sudo chown libvirt-qemu:libvirt-qemu "/var/lib/libvirt/images/${VM_NAME}-nocloud.iso"
sudo chmod 644 "/var/lib/libvirt/images/${VM_NAME}-nocloud.iso"

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ NoCloud seed ISO created: /var/lib/libvirt/images/${VM_NAME}-nocloud.iso"
echo "✅ Ready to create VM with cloud-init configuration"
