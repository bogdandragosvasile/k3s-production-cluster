#!/bin/bash

# Fix VM Network Configuration Script
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Main function
main() {
    log_info "Starting VM Network Configuration Fix"
    log_info "====================================="
    
    log_info "Restarting VMs to get fresh IP addresses..."
    
    # Restart all VMs except master-1
    for vm in k3s-master-2 k3s-master-3 k3s-worker-1 k3s-worker-2 k3s-worker-3 k3s-worker-4 k3s-worker-5 k3s-worker-6 k3s-worker-7 k3s-storage-1 k3s-storage-2 k3s-lb-1 k3s-lb-2 k3s-gpu-1; do
        log_info "Restarting $vm..."
        virsh reboot "$vm" || virsh start "$vm"
    done
    
    log_info "Waiting for VMs to restart and get IP addresses..."
    sleep 60
    
    log_info "Checking VM IP addresses..."
    virsh net-dhcp-leases default
    
    log_success "VM network configuration fix completed!"
}

# Run main function
main "$@"
