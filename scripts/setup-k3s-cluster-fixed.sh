#!/bin/bash

# K3s Cluster Setup Script (Fixed IPs)
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
    log_info "Starting K3s Cluster Setup (Fixed IPs)"
    log_info "======================================"
    
    log_info "Installing K3s on k3s-master-1..."
    sshpass -p "ubuntu" ssh -o StrictHostKeyChecking=no "ubuntu@192.168.122.241" "curl -sfL https://get.k3s.io | sh -"
    
    log_success "K3s cluster setup completed!"
}

# Run main function
main "$@"
