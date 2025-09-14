#!/bin/bash

# Initial VM Setup Script
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VM_IP="192.168.122.2"  # Default libvirt network IP
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

# Wait for VM to be accessible
wait_for_vm() {
    log_info "Waiting for VM to be accessible..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if ping -c 1 "$VM_IP" >/dev/null 2>&1; then
            log_success "VM is accessible at $VM_IP"
            return 0
        fi
        
        log_info "Waiting for VM... (attempt $((attempt + 1))/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    log_error "VM is not accessible after $max_attempts attempts"
    return 1
}

# Main function
main() {
    log_info "Starting Initial VM Setup"
    log_info "========================="
    
    # Check if sshpass is installed
    if ! command -v sshpass &> /dev/null; then
        log_info "Installing sshpass..."
        sudo apt update
        sudo apt install -y sshpass
    fi
    
    # Wait for VM to be accessible
    wait_for_vm
    
    log_success "VM setup completed!"
    log_info "VM is ready for K3s installation"
}

# Run main function
main "$@"
