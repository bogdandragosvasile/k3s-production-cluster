#!/bin/bash
# Simple K3s cluster deployment using virt-install
# This script creates a basic K3s cluster without Terraform

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="k3s-production"
BASE_IMAGE="/var/lib/libvirt/images/ubuntu-24.04-server-cloudimg-amd64.img"
SSH_KEY="$(cat ~/.ssh/k3s-cluster.pub)"

# VM configurations
declare -A VMS=(
    ["k3s-production-master-1"]="192.168.122.11:2048:2"
    ["k3s-production-master-2"]="192.168.122.12:2048:2"
    ["k3s-production-master-3"]="192.168.122.13:2048:2"
    ["k3s-production-worker-1"]="192.168.122.21:4096:2"
    ["k3s-production-worker-2"]="192.168.122.22:4096:2"
    ["k3s-production-worker-3"]="192.168.122.23:4096:2"
)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v virt-install &> /dev/null; then
        log_error "virt-install is not installed"
        exit 1
    fi
    
    if ! command -v virsh &> /dev/null; then
        log_error "virsh is not installed"
        exit 1
    fi
    
    if [[ ! -f "$BASE_IMAGE" ]]; then
        log_error "Base image not found at $BASE_IMAGE"
        exit 1
    fi
    
    if [[ ! -f ~/.ssh/k3s-cluster ]]; then
        log_error "SSH key not found at ~/.ssh/k3s-cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create cloud-init ISO
create_cloud_init() {
    local vm_name="$1"
    local ip="$2"
    
    local temp_dir=$(mktemp -d)
    local user_data_file="$temp_dir/user-data"
    local meta_data_file="$temp_dir/meta-data"
    local network_config_file="$temp_dir/network-config"
    
    # Create user-data
    cat > "$user_data_file" << EOF
#cloud-config
hostname: $vm_name
fqdn: $vm_name.k3s.local
manage_etc_hosts: true

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $SSH_KEY

ssh_pwauth: false
package_update: true
package_upgrade: true

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

timezone: UTC

runcmd:
  - systemctl enable --now qemu-guest-agent
  - apt-get update
  - apt-get upgrade -y
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  - curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - chmod +x kubectl
  - mv kubectl /usr/local/bin/
  - curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
  - echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
  - apt-get update
  - apt-get install -y helm
  - echo "* soft nofile 65536" >> /etc/security/limits.conf
  - echo "* hard nofile 65536" >> /etc/security/limits.conf
  - echo "* soft nproc 65536" >> /etc/security/limits.conf
  - echo "* hard nproc 65536" >> /etc/security/limits.conf
  - echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
  - echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  - sysctl -p
  - echo "br_netfilter" >> /etc/modules
  - echo "overlay" >> /etc/modules
  - modprobe br_netfilter
  - modprobe overlay
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  - mkdir -p /etc/containerd
  - containerd config default | tee /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  - useradd -r -s /bin/false -m -d /var/lib/rancher/k3s k3s
  - hostnamectl set-hostname $vm_name

final_message: "K3s node $vm_name is ready! SSH access available for ubuntu user."
EOF

    # Create meta-data
    cat > "$meta_data_file" << EOF
instance-id: $vm_name
local-hostname: $vm_name
EOF

    # Create network-config
    cat > "$network_config_file" << EOF
network:
  version: 2
  ethernets:
    primary-nic:
      match:
        name: en*
      dhcp4: false
      addresses: [$ip/24]
      gateway4: 192.168.122.1
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF

    # Create cloud-init ISO in temp location first
    local temp_iso="/tmp/${vm_name}-cloudinit.iso"
    genisoimage -output "$temp_iso" -volid cidata -joliet -rock "$user_data_file" "$meta_data_file" "$network_config_file"
    
    # Copy to libvirt images directory
    local iso_path="/var/lib/libvirt/images/${vm_name}-cloudinit.iso"
    sudo cp "$temp_iso" "$iso_path"
    sudo chown libvirt-qemu:kvm "$iso_path"
    sudo chmod 644 "$iso_path"
    rm "$temp_iso"
    
    # Clean up temp directory
    rm -rf "$temp_dir"
    
    echo "$iso_path"
}

# Create VM
create_vm() {
    local vm_name="$1"
    local ip="$2"
    local memory="$3"
    local vcpus="$4"
    
    log_info "Creating VM: $vm_name (IP: $ip, Memory: ${memory}MB, vCPUs: $vcpus)"
    
    # Create cloud-init ISO
    local cloud_init_iso=$(create_cloud_init "$vm_name" "$ip")
    
    # Create VM disk in temp location first
    local temp_disk="/tmp/${vm_name}.qcow2"
    qemu-img create -f qcow2 -b "$BASE_IMAGE" -F qcow2 "$temp_disk" 20G
    
    # Copy to libvirt images directory
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    sudo cp "$temp_disk" "$disk_path"
    sudo chown libvirt-qemu:kvm "$disk_path"
    sudo chmod 644 "$disk_path"
    rm "$temp_disk"
    
    # Create VM
    virt-install \
        --name "$vm_name" \
        --memory "$memory" \
        --vcpus "$vcpus" \
        --disk path="$disk_path",format=qcow2 \
        --cdrom "$cloud_init_iso" \
        --network network=default \
        --os-variant ubuntu24.04 \
        --import \
        --noautoconsole \
        --graphics none \
        --console pty,target_type=serial
    
    log_success "VM $vm_name created successfully"
}

# Wait for VM to be accessible
wait_for_vm() {
    local vm_name="$1"
    local ip="$2"
    
    log_info "Waiting for VM $vm_name to be accessible..."
    
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i ~/.ssh/k3s-cluster ubuntu@"$ip" "echo 'VM is ready'" &>/dev/null; then
            log_success "VM $vm_name is accessible"
            return 0
        fi
        
        ((attempt++))
        log_info "Attempt $attempt/$max_attempts - waiting for VM $vm_name..."
        sleep 10
    done
    
    log_error "VM $vm_name is not accessible after $max_attempts attempts"
    return 1
}

# Main deployment
main() {
    log_info "Starting simple K3s cluster deployment..."
    
    check_prerequisites
    
    # Create VMs
    for vm_name in "${!VMS[@]}"; do
        IFS=':' read -r ip memory vcpus <<< "${VMS[$vm_name]}"
        create_vm "$vm_name" "$ip" "$memory" "$vcpus"
    done
    
    # Wait for VMs to be accessible
    log_info "Waiting for all VMs to be accessible..."
    for vm_name in "${!VMS[@]}"; do
        IFS=':' read -r ip memory vcpus <<< "${VMS[$vm_name]}"
        wait_for_vm "$vm_name" "$ip"
    done
    
    log_success "All VMs are accessible!"
    
    # Display cluster information
    log_info "Cluster Information:"
    echo "===================="
    for vm_name in "${!VMS[@]}"; do
        IFS=':' read -r ip memory vcpus <<< "${VMS[$vm_name]}"
        echo "VM: $vm_name"
        echo "  IP: $ip"
        echo "  Memory: ${memory}MB"
        echo "  vCPUs: $vcpus"
        echo "  SSH: ssh -i ~/.ssh/k3s-cluster ubuntu@$ip"
        echo
    done
    
    log_success "Simple K3s cluster deployment completed!"
    log_info "Next steps:"
    log_info "1. SSH into the master nodes to install K3s"
    log_info "2. Configure the cluster with Ansible playbooks"
    log_info "3. Install Longhorn and MetalLB"
}

# Run main function
main "$@"
