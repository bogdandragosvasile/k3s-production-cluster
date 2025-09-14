#!/bin/bash
# K3s Production Cluster - Comprehensive Deployment Script
# Based on patterns from k8s-libvirt-cluster repository
# Orchestrates Terraform infrastructure + Ansible configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="k3s-production"
BASE_IMAGE_PATH="/var/lib/libvirt/images/ubuntu-24.04-cloudimg-amd64.img"
SSH_KEY_PATH="$HOME/.ssh/k3s-cluster"
TERRAFORM_DIR="/home/bogdan/GitHub/k3s-production-cluster/terraform"
ANSIBLE_DIR="/home/bogdan/GitHub/k3s-production-cluster/ansible"
SCRIPTS_DIR="/home/bogdan/GitHub/k3s-production-cluster/scripts"

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
    log_info "=== Checking Prerequisites ==="
    
    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo access."
        exit 1
    fi
    
    # Check if user has sudo access
    if ! sudo -n true 2>/dev/null; then
        log_error "This script requires sudo access. Please run: sudo visudo"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("terraform" "ansible" "ansible-playbook" "virsh" "qemu-img")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found. Please install it first."
            exit 1
        fi
    done
    
    # Check if base image exists
    if [[ ! -f "$BASE_IMAGE_PATH" ]]; then
        log_error "Base image not found at $BASE_IMAGE_PATH"
        log_info "Please download Ubuntu 24.04 LTS cloud image first:"
        log_info "  wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img -O $BASE_IMAGE_PATH"
        exit 1
    fi
    
    # Check if SSH key exists
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        log_error "SSH key not found at $SSH_KEY_PATH"
        log_info "Please generate SSH key first:"
        log_info "  ssh-keygen -t ed25519 -f $SSH_KEY_PATH -C 'k3s-cluster@production'"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

# Clean up any existing deployment
cleanup_existing() {
    log_info "=== Cleaning Up Existing Deployment ==="
    
    if [[ -f "$SCRIPTS_DIR/cleanup-cluster.sh" ]]; then
        log_info "Running cleanup script..."
        echo "yes" | sudo "$SCRIPTS_DIR/cleanup-cluster.sh"
    else
        log_warning "Cleanup script not found, performing manual cleanup..."
        
        # Stop and undefine any existing VMs
        for vm in $(sudo virsh list --all --name | grep -i k3s || true); do
            if [[ -n "$vm" ]]; then
                log_info "Stopping and undefining VM: $vm"
                sudo virsh destroy "$vm" &>/dev/null || true
                sudo virsh undefine "$vm" --remove-all-storage &>/dev/null || true
            fi
        done
        
        # Clean up Terraform state
        if [[ -d "$TERRAFORM_DIR" ]]; then
            cd "$TERRAFORM_DIR"
            if [[ -f "terraform.tfstate" ]]; then
                terraform destroy -auto-approve || true
            fi
            rm -f terraform.tfstate* .terraform.lock.hcl
            rm -rf .terraform/
        fi
    fi
    
    log_success "Cleanup completed"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "=== Deploying Infrastructure with Terraform ==="
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log_info "Planning Terraform deployment..."
    terraform plan -var="ssh_public_key=$(cat "$SSH_KEY_PATH.pub")" -out=tfplan
    
    # Apply deployment
    log_info "Applying Terraform deployment..."
    terraform apply tfplan
    
    # Wait for VMs to be ready
    log_info "Waiting for VMs to be ready..."
    sleep 30
    
    # Check VM status
    log_info "Checking VM status..."
    sudo virsh list --all | grep k3s || true
    
    log_success "Infrastructure deployed successfully"
}

# Wait for VMs to be accessible
wait_for_vms() {
    log_info "=== Waiting for VMs to be Accessible ==="
    
    # Get VM IPs from Terraform output
    local vm_ips
    vm_ips=$(cd "$TERRAFORM_DIR" && terraform output -json vm_ips | jq -r 'to_entries[] | "\(.value)"')
    
    if [[ -z "$vm_ips" ]]; then
        log_error "Could not get VM IPs from Terraform output"
        exit 1
    fi
    
    log_info "Waiting for VMs to be accessible via SSH..."
    local max_attempts=30
    local attempt=0
    
    for ip in $vm_ips; do
        log_info "Waiting for VM at $ip..."
        attempt=0
        while [[ $attempt -lt $max_attempts ]]; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$SSH_KEY_PATH" "ubuntu@$ip" "echo 'VM ready'" &>/dev/null; then
                log_success "VM at $ip is ready"
                break
            fi
            ((attempt++))
            sleep 10
        done
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "VM at $ip is not accessible after $max_attempts attempts"
            exit 1
        fi
    done
    
    log_success "All VMs are accessible"
}

# Deploy K3s cluster with Ansible
deploy_k3s_cluster() {
    log_info "=== Deploying K3s Cluster with Ansible ==="
    
    cd "$ANSIBLE_DIR"
    
    # Test Ansible connectivity
    log_info "Testing Ansible connectivity..."
    ansible all -m ping
    
    # Deploy K3s cluster
    log_info "Deploying K3s cluster..."
    ansible-playbook -i inventory.yml playbooks/k3s-cluster.yml
    
    log_success "K3s cluster deployed successfully"
}

# Deploy Longhorn storage
deploy_longhorn() {
    log_info "=== Deploying Longhorn Storage ==="
    
    cd "$ANSIBLE_DIR"
    
    # Deploy Longhorn
    log_info "Deploying Longhorn..."
    ansible-playbook -i inventory.yml playbooks/longhorn.yml
    
    log_success "Longhorn deployed successfully"
}

# Deploy MetalLB load balancer
deploy_metallb() {
    log_info "=== Deploying MetalLB Load Balancer ==="
    
    cd "$ANSIBLE_DIR"
    
    # Deploy MetalLB
    log_info "Deploying MetalLB..."
    ansible-playbook -i inventory.yml playbooks/metallb.yml
    
    log_success "MetalLB deployed successfully"
}

# Verify cluster health
verify_cluster() {
    log_info "=== Verifying Cluster Health ==="
    
    # Get master node IP
    local master_ip
    master_ip=$(cd "$TERRAFORM_DIR" && terraform output -json vm_ips | jq -r '.["k3s-production-master-1"]')
    
    if [[ -z "$master_ip" ]]; then
        log_error "Could not get master node IP"
        exit 1
    fi
    
    # Copy kubeconfig
    log_info "Copying kubeconfig from master node..."
    scp -i "$SSH_KEY_PATH" "ubuntu@$master_ip:/etc/rancher/k3s/k3s.yaml" "$HOME/.kube/config"
    
    # Update kubeconfig server URL
    sed -i "s/127.0.0.1/$master_ip/g" "$HOME/.kube/config"
    
    # Test kubectl
    log_info "Testing kubectl connectivity..."
    kubectl get nodes
    
    # Check cluster status
    log_info "Checking cluster status..."
    kubectl get pods --all-namespaces
    
    # Check Longhorn status
    log_info "Checking Longhorn status..."
    kubectl get pods -n longhorn-system
    
    # Check MetalLB status
    log_info "Checking MetalLB status..."
    kubectl get pods -n metallb-system
    
    log_success "Cluster verification completed"
}

# Display cluster information
display_cluster_info() {
    log_info "=== Cluster Information ==="
    
    cd "$TERRAFORM_DIR"
    
    # Get cluster info
    local cluster_info
    cluster_info=$(terraform output -json cluster_info)
    
    echo ""
    echo "🎉 K3s Production Cluster Deployed Successfully!"
    echo ""
    echo "Cluster Details:"
    echo "  Name: $(echo "$cluster_info" | jq -r '.cluster_name')"
    echo "  Total Nodes: $(echo "$cluster_info" | jq -r '.total_nodes')"
    echo "  Masters: $(echo "$cluster_info" | jq -r '.masters')"
    echo "  Workers: $(echo "$cluster_info" | jq -r '.workers')"
    echo "  Storage: $(echo "$cluster_info" | jq -r '.storage')"
    echo "  Load Balancers: $(echo "$cluster_info" | jq -r '.load_balancers')"
    echo ""
    echo "VM IPs:"
    terraform output vm_ips | jq -r 'to_entries[] | "  \(.key): \(.value)"'
    echo ""
    echo "Access Information:"
    echo "  SSH Key: $SSH_KEY_PATH"
    echo "  Kubeconfig: $HOME/.kube/config"
    echo ""
    echo "Useful Commands:"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl get svc --all-namespaces"
    echo ""
    echo "To clean up the cluster:"
    echo "  $SCRIPTS_DIR/cleanup-cluster.sh"
    echo ""
}

# Main execution
main() {
    log_info "Starting K3s Production Cluster Deployment..."
    log_warning "This will deploy a complete K3s cluster with Longhorn and MetalLB"
    
    # Confirmation prompt
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Deployment cancelled by user"
        exit 0
    fi
    
    check_prerequisites
    cleanup_existing
    deploy_infrastructure
    wait_for_vms
    deploy_k3s_cluster
    deploy_longhorn
    deploy_metallb
    verify_cluster
    display_cluster_info
    
    log_success "=== Deployment Complete! ==="
}

# Run main function
main "$@"