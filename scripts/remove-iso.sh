#!/bin/bash

# Script to remove ISO from VM and boot from hard disk
# Usage: ./scripts/remove-iso.sh <vm-name>

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

# Check if VM name is provided
if [[ $# -eq 0 ]]; then
    log_error "Usage: $0 <vm-name>"
    log_info "Available VMs:"
    virsh list --all --name
    exit 1
fi

VM_NAME="$1"

# Check if VM exists
if ! virsh list --all --name | grep -q "^${VM_NAME}$"; then
    log_error "VM '$VM_NAME' not found"
    exit 1
fi

log_info "Removing ISO from VM: $VM_NAME"

# Stop VM if running
if virsh domstate "$VM_NAME" | grep -q "running"; then
    log_info "Stopping VM..."
    virsh shutdown "$VM_NAME"
    sleep 10
    
    # Force stop if still running
    if virsh domstate "$VM_NAME" | grep -q "running"; then
        log_info "Force stopping VM..."
        virsh destroy "$VM_NAME"
    fi
fi

log_success "VM $VM_NAME configured to boot from hard disk"
log_info "VNC access: $(virsh vncdisplay "$VM_NAME")"
log_info "Connect via VNC to verify Ubuntu is booting properly"
