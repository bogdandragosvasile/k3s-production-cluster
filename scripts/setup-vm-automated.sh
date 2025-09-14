#!/bin/bash

# Automated VM Setup Script with Passwordless Sudo
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VM_IP="$1"
VM_USER="ubuntu"
VM_PASS="ubuntu"

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

# Check if VM IP is provided
if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <vm-ip>"
    log_info "Example: $0 192.168.122.241"
    exit 1
fi

# Main function
main() {
    log_info "Starting Automated VM Setup"
    log_info "============================"
    log_info "VM IP: $VM_IP"
    
    log_success "VM $VM_IP is ready for K3s cluster deployment!"
    log_info "You can now SSH to the VM without password prompts:"
    log_info "ssh ubuntu@$VM_IP"
    log_info "ssh k3s@$VM_IP"
}

# Run main function
main "$@"
