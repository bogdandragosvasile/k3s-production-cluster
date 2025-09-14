#!/bin/bash

# Add Second Network Interface by Modifying VM XML
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

# Add second network interface to VM
add_second_nic() {
    local vm_name="$1"
    
    log_info "Adding second network interface to $vm_name..."
    
    # Shutdown VM if running
    if virsh domstate "$vm_name" | grep -q "running"; then
        log_info "Shutting down $vm_name..."
        virsh shutdown "$vm_name" --mode acpi
        sleep 10
        if virsh domstate "$vm_name" | grep -q "running"; then
            log_info "Force stopping $vm_name..."
            virsh destroy "$vm_name"
        fi
    fi
    
    # Dump current XML
    virsh dumpxml "$vm_name" > "/tmp/${vm_name}-current.xml"
    
    # Add second network interface before closing </devices> tag
    sed -i '/<\/devices>/i\    <interface type="network">\n      <source network="default"/>\n      <model type="virtio"/>\n      <address type="pci" domain="0x0000" bus="0x00" slot="0x04" function="0x0"/>\n    </interface>' "/tmp/${vm_name}-current.xml"
    
    # Undefine and redefine VM
    virsh undefine "$vm_name" --nvram
    virsh define "/tmp/${vm_name}-current.xml"
    
    # Start VM
    virsh start "$vm_name"
    
    log_success "Second network interface added to $vm_name"
}

# Main function
main() {
    log_info "Adding Second Network Interfaces to VMs"
    log_info "======================================="
    
    # Add second NICs to all VMs
    for vm in "${VMS[@]}"; do
        add_second_nic "$vm" &
    done
    
    # Wait for all VMs to be processed
    wait
    
    log_info "Waiting for VMs to get IP addresses..."
    sleep 60
    
    log_info "Checking VM IP addresses..."
    virsh net-dhcp-leases default
    
    log_success "Second network interfaces added to all VMs!"
}

# Run main function
main "$@"
