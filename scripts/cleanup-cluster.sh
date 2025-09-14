#!/bin/bash
# Comprehensive K3s Cluster Cleanup Script
# Based on patterns from k8s-libvirt-cluster repository
# Removes all K3s-related VMs, storage, and resets networking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="k3s-production"
BASE_IMAGE="ubuntu-24.04-cloudimg-amd64.img"
IMAGES_DIR="/var/lib/libvirt/images"
LIBVIRT_DEFAULT_XML="/usr/share/libvirt/networks/default.xml"

# VM name patterns for K3s cluster
VM_PATTERNS=(
  "k3s-production-master-1"
  "k3s-production-master-2" 
  "k3s-production-master-3"
  "k3s-production-worker-1"
  "k3s-production-worker-2"
  "k3s-production-worker-3"
  "k3s-production-storage-1"
  "k3s-production-storage-2"
  "k3s-production-lb-1"
  "k3s-production-lb-2"
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

# Check if running as root or with sudo
check_privileges() {
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log_error "This script requires root privileges or sudo access"
        exit 1
    fi
}

# Stop and undefine VMs
cleanup_vms() {
    log_info "=== Stopping and undefining VMs ==="
    
    for vm in "${VM_PATTERNS[@]}"; do
        if sudo virsh dominfo "$vm" &>/dev/null; then
            log_info "Stopping VM: $vm"
            sudo virsh destroy "$vm" &>/dev/null || true
            
            log_info "Undefining VM: $vm"
            sudo virsh undefine "$vm" --remove-all-storage &>/dev/null || true
            log_success "VM $vm cleaned up"
        else
            log_info "VM $vm not found, skipping"
        fi
    done
    
    # Also clean up any VMs with k3s in the name
    log_info "Cleaning up any remaining K3s VMs..."
    for vm in $(sudo virsh list --all --name | grep -i k3s || true); do
        if [[ -n "$vm" ]]; then
            log_info "Found additional K3s VM: $vm"
            sudo virsh destroy "$vm" &>/dev/null || true
            sudo virsh undefine "$vm" --remove-all-storage &>/dev/null || true
            log_success "Additional VM $vm cleaned up"
        fi
    done
}

# Remove leftover disk images
cleanup_storage() {
    log_info "=== Removing leftover VM disk images (except base image) ==="
    
    # Remove cluster-specific directories
    if [[ -d "$IMAGES_DIR/$CLUSTER_NAME" ]]; then
        log_info "Removing cluster directory: $IMAGES_DIR/$CLUSTER_NAME"
        sudo rm -rf "$IMAGES_DIR/$CLUSTER_NAME"
    fi
    
    # Remove individual disk images
    for img in "$IMAGES_DIR"/*; do
        if [[ -f "$img" ]]; then
            fname=$(basename "$img")
            if [[ "$fname" != "$BASE_IMAGE" ]] && [[ "$fname" =~ k3s|production ]]; then
                log_info "Deleting disk: $fname"
                sudo rm -f "$img"
            fi
        fi
    done
    
    # Clean up any cloud-init ISOs
    for iso in "$IMAGES_DIR"/*.iso; do
        if [[ -f "$iso" ]] && [[ "$iso" =~ k3s|production ]]; then
            log_info "Deleting cloud-init ISO: $(basename "$iso")"
            sudo rm -f "$iso"
        fi
    done
}

# Reset libvirt default network
reset_network() {
    log_info "=== Resetting Libvirt default network ==="
    
    # Stop and undefine default network
    sudo virsh net-destroy default &>/dev/null || true
    sudo virsh net-undefine default &>/dev/null || true
    
    # Restore from factory template
    if [[ -f "$LIBVIRT_DEFAULT_XML" ]]; then
        sudo virsh net-define "$LIBVIRT_DEFAULT_XML"
        sudo virsh net-start default
        sudo virsh net-autostart default
        log_success "Default network restored from: $LIBVIRT_DEFAULT_XML"
    else
        log_warning "Default network template not found at $LIBVIRT_DEFAULT_XML"
        log_info "Creating basic default network..."
        sudo virsh net-define - <<EOF
<network>
  <name>default</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
        sudo virsh net-start default
        sudo virsh net-autostart default
        log_success "Basic default network created"
    fi
}

# Clean up Terraform state
cleanup_terraform() {
    log_info "=== Cleaning up Terraform state ==="
    
    if [[ -d "/home/bogdan/GitHub/k3s-production-cluster/terraform" ]]; then
        cd "/home/bogdan/GitHub/k3s-production-cluster/terraform"
        
        if [[ -f "terraform.tfstate" ]] || [[ -f ".terraform.lock.hcl" ]]; then
            log_info "Destroying Terraform resources..."
            terraform destroy -auto-approve || true
            
            log_info "Cleaning up Terraform state files..."
            rm -f terraform.tfstate* .terraform.lock.hcl
            rm -rf .terraform/
            log_success "Terraform state cleaned up"
        else
            log_info "No Terraform state found, skipping"
        fi
    else
        log_info "Terraform directory not found, skipping"
    fi
}

# Clean up Ansible inventory
cleanup_ansible() {
    log_info "=== Cleaning up Ansible inventory ==="
    
    if [[ -f "/home/bogdan/GitHub/k3s-production-cluster/ansible/inventory.yml" ]]; then
        # Reset inventory to empty state
        cat > "/home/bogdan/GitHub/k3s-production-cluster/ansible/inventory.yml" <<EOF
all:
  children:
    masters:
      hosts: {}
    workers:
      hosts: {}
    storage:
      hosts: {}
    load_balancers:
      hosts: {}
EOF
        log_success "Ansible inventory reset"
    fi
}

# Verify cleanup
verify_cleanup() {
    log_info "=== Verifying cleanup ==="
    
    log_info "Remaining images in $IMAGES_DIR:"
    ls -lh "$IMAGES_DIR" | grep -E "(k3s|production)" || log_success "No K3s-related images found"
    
    log_info "Active VMs:"
    sudo virsh list --all | grep -i k3s || log_success "No K3s VMs found"
    
    log_info "Network status:"
    sudo virsh net-list --all
    
    log_info "Storage pools:"
    sudo virsh pool-list --all
}

# Main execution
main() {
    log_info "Starting comprehensive K3s cluster cleanup..."
    log_warning "This will destroy all K3s VMs and related resources!"
    
    # Confirmation prompt
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
    
    check_privileges
    cleanup_vms
    cleanup_storage
    reset_network
    cleanup_terraform
    cleanup_ansible
    verify_cleanup
    
    log_success "=== Cleanup complete! ==="
    log_info "You can now run a fresh deployment from a clean state."
    log_info "Run: cd /home/bogdan/GitHub/k3s-production-cluster && ./scripts/deploy-k3s-cluster.sh"
}

# Run main function
main "$@"

