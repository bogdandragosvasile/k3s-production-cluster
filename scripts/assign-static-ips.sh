#!/bin/bash

# Assign Static IPs to VMs
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# VM Configuration
declare -A VM_IPS=(
    ["k3s-master-1"]="192.168.122.241"
    ["k3s-master-2"]="192.168.122.242"
    ["k3s-master-3"]="192.168.122.243"
    ["k3s-worker-1"]="192.168.122.244"
    ["k3s-worker-2"]="192.168.122.245"
    ["k3s-worker-3"]="192.168.122.246"
    ["k3s-worker-4"]="192.168.122.247"
    ["k3s-worker-5"]="192.168.122.248"
    ["k3s-worker-6"]="192.168.122.249"
    ["k3s-worker-7"]="192.168.122.250"
    ["k3s-storage-1"]="192.168.122.251"
    ["k3s-storage-2"]="192.168.122.252"
    ["k3s-lb-1"]="192.168.122.253"
    ["k3s-lb-2"]="192.168.122.254"
    ["k3s-gpu-1"]="192.168.122.100"
)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Main function
main() {
    log_info "Assigning Static IPs to VMs"
    log_info "============================"
    
    # Update libvirt network with static IP assignments
    log_info "Updating libvirt network with static IP assignments..."
    
    # Create new network configuration with static IPs
    cat > /tmp/static-network.xml << 'NETWORK_EOF'
<network>
  <name>default</name>
  <uuid>2006daf1-8e60-464c-bfd3-8e45b5cdd091</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <mac address='52:54:00:5f:3c:ae'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.99'/>
      <host mac='52:54:00:c5:fe:50' name='k3s-master-1' ip='192.168.122.241'/>
      <host mac='52:54:00:65:f6:32' name='k3s-master-2' ip='192.168.122.242'/>
      <host mac='52:54:00:b7:9b:a5' name='k3s-master-3' ip='192.168.122.243'/>
      <host mac='52:54:00:2a:d2:53' name='k3s-worker-1' ip='192.168.122.244'/>
      <host mac='52:54:00:93:11:76' name='k3s-worker-2' ip='192.168.122.245'/>
      <host mac='52:54:00:d4:81:4f' name='k3s-worker-3' ip='192.168.122.246'/>
    </dhcp>
  </ip>
</network>
NETWORK_EOF
    
    # Update the network
    virsh net-destroy default
    virsh net-define /tmp/static-network.xml
    virsh net-start default
    virsh net-autostart default
    
    log_success "Network updated with static IP assignments"
    
    # Restart VMs to get new IPs
    log_info "Restarting VMs to get static IPs..."
    for vm in k3s-master-2 k3s-master-3 k3s-worker-1 k3s-worker-2 k3s-worker-3; do
        log_info "Restarting $vm..."
        virsh reboot "$vm" || virsh start "$vm"
    done
    
    log_info "Waiting for VMs to get static IPs..."
    sleep 30
    
    log_info "Checking VM IP addresses..."
    virsh net-dhcp-leases default
    
    log_success "Static IP assignment completed!"
}

# Run main function
main "$@"
