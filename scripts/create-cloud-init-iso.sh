#!/bin/bash

# Cloud-init ISO Creation Script
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Install cloud-image-utils if not present
    if ! command -v cloud-localds &> /dev/null; then
        log_info "Installing cloud-image-utils..."
        apt-get update
        apt-get install -y cloud-image-utils
    fi
    
    # Create ISO directory
    mkdir -p /var/lib/libvirt/images/cloud-init-isos
    
    log_success "Prerequisites check completed"
}

# Main function
main() {
    log_info "Starting Cloud-init ISO Creation"
    log_info "================================="
    
    check_prerequisites
    
    log_success "Cloud-init ISO Creation setup completed!"
    log_info "Next: Run the VM creation script"
}

# Run main function
main "$@"
