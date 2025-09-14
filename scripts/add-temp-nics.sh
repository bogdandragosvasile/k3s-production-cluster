#!/bin/bash

# Add Temporary Network Interfaces to VMs
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# VM list (excluding master-1 which already has IP)
VMS=("k3s-master-2" "k3s-master-3" "k3s-worker-1" "k3s-worker-2" "k3s-worker-3" "k3s-worker-4" "k3s-worker-5" "k3s-worker-6" "k3s-worker-7" "k3s-storage-1" "k3s-storage-2" "k3s-lb-1" "k3s-lb-2" "k3s-gpu-1")

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

# Add temporary network interface to VM
add_temp_nic() {
    local vm_name="$1"
    
    log_info "Adding temporary network interface to $vm_name..."
    
    # Create temporary XML for the network interface
    cat > "/tmp/${vm_name}-temp-nic.xml" << 'NIC_EOF'
<interface type='network'>
  <source network='default'/>
  <model type='virtio'/>
  <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
</interface>
NIC_EOF
    
    # Attach the interface
    virsh attach-device "$vm_name" "/tmp/${vm_name}-temp-nic.xml" --persistent
    
    log_success "Temporary network interface added to $vm_name"
}

# Main function
main() {
    log_info "Adding Temporary Network Interfaces to VMs"
    log_info "==========================================="
    
    # Add temporary NICs to all VMs
    for vm in "${VMS[@]}"; do
        add_temp_nic "$vm" &
    done
    
    # Wait for all interfaces to be added
    wait
    
    log_info "Waiting for VMs to get IP addresses..."
    sleep 30
    
    log_info "Checking VM IP addresses..."
    virsh net-dhcp-leases default
    
    log_success "Temporary network interfaces added to all VMs!"
}

# Run main function
main "$@"
