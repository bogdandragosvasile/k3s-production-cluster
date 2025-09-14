#!/bin/bash

# K3s Cluster Setup Script
# This script installs and configures K3s on the deployed VMs

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# VM Configuration
MASTER_VMS=("k3s-master-1" "k3s-master-2" "k3s-master-3")
WORKER_VMS=("k3s-worker-1" "k3s-worker-2" "k3s-worker-3" "k3s-worker-4" "k3s-worker-5" "k3s-worker-6" "k3s-worker-7")
STORAGE_VMS=("k3s-storage-1" "k3s-storage-2")
GPU_VMS=("k3s-gpu-1")

# Network Configuration
MASTER_IPS=("192.168.1.11" "192.168.1.12" "192.168.1.13")
WORKER_IPS=("192.168.1.21" "192.168.1.22" "192.168.1.23" "192.168.1.24" "192.168.1.25" "192.168.1.26" "192.168.1.27")
STORAGE_IPS=("192.168.1.31" "192.168.1.32")
GPU_IPS=("192.168.1.50")

# K3s Configuration
K3S_VERSION="v1.31.3+k3s1"
CLUSTER_DOMAIN="k3s.local"
POD_CIDR="10.42.0.0/16"
SERVICE_CIDR="10.43.0.0/16"
CLUSTER_DNS="10.43.0.10"

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

# SSH configuration
setup_ssh() {
    local vm_name="$1"
    local vm_ip="$2"
    
    log_info "Setting up SSH for $vm_name ($vm_ip)"
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f ~/.ssh/id_rsa ]]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    fi
    
    # Copy SSH key to VM (assuming password authentication is enabled)
    log_warning "Please enter the password for $vm_name when prompted"
    ssh-copy-id -o StrictHostKeyChecking=no root@$vm_ip || {
        log_error "Failed to copy SSH key to $vm_name"
        return 1
    }
    
    log_success "SSH setup completed for $vm_name"
}

# Install K3s on master nodes
install_k3s_master() {
    local vm_name="$1"
    local vm_ip="$2"
    local is_first="$3"
    
    log_info "Installing K3s master on $vm_name ($vm_ip)"
    
    local k3s_install_cmd="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION sh -s - server"
    
    if [[ "$is_first" == "true" ]]; then
        # First master - initialize cluster
        k3s_install_cmd+=" --cluster-init"
    else
        # Additional masters - join existing cluster
        local first_master_ip="${MASTER_IPS[0]}"
        k3s_install_cmd+=" --server https://$first_master_ip:6443"
    fi
    
    # Add K3s server arguments
    k3s_install_cmd+=" --disable=traefik --disable=servicelb --disable=local-storage"
    k3s_install_cmd+=" --write-kubeconfig-mode=644"
    k3s_install_cmd+=" --tls-san=192.168.1.200 --tls-san=k3s-api.$CLUSTER_DOMAIN"
    k3s_install_cmd+=" --cluster-cidr=$POD_CIDR --service-cidr=$SERVICE_CIDR --cluster-dns=$CLUSTER_DNS"
    k3s_install_cmd+=" --disable-network-policy --flannel-backend=vxlan"
    
    # Execute installation
    ssh root@$vm_ip "$k3s_install_cmd" || {
        log_error "Failed to install K3s on $vm_name"
        return 1
    }
    
    log_success "K3s master installed on $vm_name"
}

# Install K3s on worker nodes
install_k3s_worker() {
    local vm_name="$1"
    local vm_ip="$2"
    
    log_info "Installing K3s worker on $vm_name ($vm_ip)"
    
    # Get token from first master
    local first_master_ip="${MASTER_IPS[0]}"
    local k3s_token=$(ssh root@$first_master_ip "cat /var/lib/rancher/k3s/server/node-token")
    
    # Install K3s agent
    local k3s_install_cmd="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$first_master_ip:6443 K3S_TOKEN=$k3s_token sh -s - agent"
    
    # Add agent arguments
    k3s_install_cmd+=" --node-name=$vm_name"
    k3s_install_cmd+=" --kubelet-arg=feature-gates=KubeletInUserNamespace=true"
    
    # Execute installation
    ssh root@$vm_ip "$k3s_install_cmd" || {
        log_error "Failed to install K3s worker on $vm_name"
        return 1
    }
    
    log_success "K3s worker installed on $vm_name"
}

# Install K3s on storage nodes
install_k3s_storage() {
    local vm_name="$1"
    local vm_ip="$2"
    
    log_info "Installing K3s storage node on $vm_name ($vm_ip)"
    
    # Get token from first master
    local first_master_ip="${MASTER_IPS[0]}"
    local k3s_token=$(ssh root@$first_master_ip "cat /var/lib/rancher/k3s/server/node-token")
    
    # Install K3s agent
    local k3s_install_cmd="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$first_master_ip:6443 K3S_TOKEN=$k3s_token sh -s - agent"
    
    # Add agent arguments
    k3s_install_cmd+=" --node-name=$vm_name"
    k3s_install_cmd+=" --kubelet-arg=feature-gates=KubeletInUserNamespace=true"
    
    # Execute installation
    ssh root@$vm_ip "$k3s_install_cmd" || {
        log_error "Failed to install K3s storage node on $vm_name"
        return 1
    }
    
    log_success "K3s storage node installed on $vm_name"
}

# Install K3s on GPU node
install_k3s_gpu() {
    local vm_name="$1"
    local vm_ip="$2"
    
    log_info "Installing K3s GPU node on $vm_name ($vm_ip)"
    
    # Get token from first master
    local first_master_ip="${MASTER_IPS[0]}"
    local k3s_token=$(ssh root@$first_master_ip "cat /var/lib/rancher/k3s/server/node-token")
    
    # Install K3s agent
    local k3s_install_cmd="curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_URL=https://$first_master_ip:6443 K3S_TOKEN=$k3s_token sh -s - agent"
    
    # Add agent arguments
    k3s_install_cmd+=" --node-name=$vm_name"
    k3s_install_cmd+=" --kubelet-arg=feature-gates=KubeletInUserNamespace=true"
    
    # Execute installation
    ssh root@$vm_ip "$k3s_install_cmd" || {
        log_error "Failed to install K3s GPU node on $vm_name"
        return 1
    }
    
    log_success "K3s GPU node installed on $vm_name"
}

# Configure kubectl
configure_kubectl() {
    local first_master_ip="${MASTER_IPS[0]}"
    
    log_info "Configuring kubectl"
    
    # Copy kubeconfig from first master
    scp root@$first_master_ip:/etc/rancher/k3s/k3s.yaml ~/.kube/config
    
    # Update server address in kubeconfig
    sed -i "s/127.0.0.1/$first_master_ip/g" ~/.kube/config
    
    # Set proper permissions
    chmod 600 ~/.kube/config
    
    log_success "kubectl configured"
}

# Wait for cluster to be ready
wait_for_cluster() {
    log_info "Waiting for cluster to be ready..."
    
    local first_master_ip="${MASTER_IPS[0]}"
    
    # Wait for nodes to be ready
    local max_attempts=60
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if kubectl get nodes --no-headers | grep -q "Ready"; then
            log_success "Cluster is ready"
            return 0
        fi
        
        log_info "Waiting for cluster... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    log_error "Cluster failed to become ready within expected time"
    return 1
}

# Label nodes
label_nodes() {
    log_info "Labeling nodes"
    
    # Label worker nodes
    for i in "${!WORKER_VMS[@]}"; do
        kubectl label node "${WORKER_VMS[$i]}" node-role.kubernetes.io/worker=true
        kubectl label node "${WORKER_VMS[$i]}" node-type=worker
    done
    
    # Label storage nodes
    for i in "${!STORAGE_VMS[@]}"; do
        kubectl label node "${STORAGE_VMS[$i]}" node-role.kubernetes.io/storage=true
        kubectl label node "${STORAGE_VMS[$i]}" node-type=storage
    done
    
    # Label GPU node
    kubectl label node "${GPU_VMS[0]}" node-role.kubernetes.io/gpu=true
    kubectl label node "${GPU_VMS[0]}" node-type=gpu
    kubectl label node "${GPU_VMS[0]}" accelerator=amd-gpu
    
    log_success "Nodes labeled"
}

# Install additional tools
install_tools() {
    local first_master_ip="${MASTER_IPS[0]}"
    
    log_info "Installing additional tools on master nodes"
    
    # Install helm
    ssh root@$first_master_ip "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    
    # Install kubectl
    ssh root@$first_master_ip "curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/"
    
    log_success "Additional tools installed"
}

# Main function
main() {
    log_info "Starting K3s Cluster Setup"
    log_info "=========================="
    
    # Setup SSH for all VMs
    log_info "Setting up SSH for all VMs..."
    
    # Master nodes
    for i in "${!MASTER_VMS[@]}"; do
        setup_ssh "${MASTER_VMS[$i]}" "${MASTER_IPS[$i]}"
    done
    
    # Worker nodes
    for i in "${!WORKER_VMS[@]}"; do
        setup_ssh "${WORKER_VMS[$i]}" "${WORKER_IPS[$i]}"
    done
    
    # Storage nodes
    for i in "${!STORAGE_VMS[@]}"; do
        setup_ssh "${STORAGE_VMS[$i]}" "${STORAGE_IPS[$i]}"
    done
    
    # GPU node
    setup_ssh "${GPU_VMS[0]}" "${GPU_IPS[0]}"
    
    # Install K3s on master nodes
    log_info "Installing K3s on master nodes..."
    for i in "${!MASTER_VMS[@]}"; do
        if [[ $i -eq 0 ]]; then
            install_k3s_master "${MASTER_VMS[$i]}" "${MASTER_IPS[$i]}" "true"
        else
            install_k3s_master "${MASTER_VMS[$i]}" "${MASTER_IPS[$i]}" "false"
        fi
    done
    
    # Install K3s on worker nodes
    log_info "Installing K3s on worker nodes..."
    for i in "${!WORKER_VMS[@]}"; do
        install_k3s_worker "${WORKER_VMS[$i]}" "${WORKER_IPS[$i]}"
    done
    
    # Install K3s on storage nodes
    log_info "Installing K3s on storage nodes..."
    for i in "${!STORAGE_VMS[@]}"; do
        install_k3s_storage "${STORAGE_VMS[$i]}" "${STORAGE_IPS[$i]}"
    done
    
    # Install K3s on GPU node
    log_info "Installing K3s on GPU node..."
    install_k3s_gpu "${GPU_VMS[0]}" "${GPU_IPS[0]}"
    
    # Configure kubectl
    configure_kubectl
    
    # Wait for cluster
    wait_for_cluster
    
    # Label nodes
    label_nodes
    
    # Install additional tools
    install_tools
    
    log_success "K3s Cluster Setup Completed!"
    log_info "Cluster Information:"
    log_info "==================="
    kubectl get nodes -o wide
    log_info ""
    log_info "Next steps:"
    log_info "1. Run: ./scripts/setup-longhorn.sh"
    log_info "2. Run: ./scripts/setup-metallb.sh"
    log_info "3. Run: ./scripts/setup-traefik.sh"
}

# Run main function
main "$@"
