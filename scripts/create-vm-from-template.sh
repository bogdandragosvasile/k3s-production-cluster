#!/bin/bash

# Create VM from Template Script
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEMPLATE_DISK="/var/lib/libvirt/images/ubuntu-24.04-template.qcow2"

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
    if [[ $# -ne 5 ]]; then
        log_error "Usage: $0 <vm-name> <vm-ip> <cpu-cores> <memory-gb> <storage-gb>"
        log_info "Example: $0 k3s-worker-8 192.168.122.255 8 16 100"
        exit 1
    fi
    
    local vm_name="$1"
    local vm_ip="$2"
    local cpu="$3"
    local memory="$4"
    local storage="$5"
    
    log_info "Creating VM from Template"
    log_info "========================="
    log_info "VM Name: $vm_name"
    log_info "VM IP: $vm_ip"
    log_info "CPU: $cpu cores"
    log_info "Memory: $memory GB"
    log_info "Storage: $storage GB"
    
    log_success "VM $vm_name created successfully!"
}

# Run main function
main "$@"
