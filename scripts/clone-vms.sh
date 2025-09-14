#!/bin/bash

# VM Cloning Script
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SOURCE_VM="k3s-master-1"
SOURCE_DISK="/var/lib/libvirt/images/k3s-master-1.qcow2"

# VM Configuration
declare -A VM_CONFIGS=(
    ["k3s-master-2"]="192.168.122.242:4:8:50"
    ["k3s-master-3"]="192.168.122.243:4:8:50"
    ["k3s-worker-1"]="192.168.122.244:8:16:100"
    ["k3s-worker-2"]="192.168.122.245:8:16:100"
    ["k3s-worker-3"]="192.168.122.246:8:16:100"
    ["k3s-worker-4"]="192.168.122.247:8:16:100"
    ["k3s-worker-5"]="192.168.122.248:8:16:100"
    ["k3s-worker-6"]="192.168.122.249:8:16:100"
    ["k3s-worker-7"]="192.168.122.250:8:16:100"
    ["k3s-storage-1"]="192.168.122.251:4:8:200"
    ["k3s-storage-2"]="192.168.122.252:4:8:200"
    ["k3s-lb-1"]="192.168.122.253:2:4:20"
    ["k3s-lb-2"]="192.168.122.254:2:4:20"
    ["k3s-gpu-1"]="192.168.122.100:12:24:100"
)

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

# Clone VM disk
clone_vm_disk() {
    local vm_name="$1"
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    
    log_info "Cloning disk for $vm_name..."
    
    if [[ -f "$disk_path" ]]; then
        log_warning "Disk $disk_path already exists, removing it..."
        rm -f "$disk_path"
    fi
    
    # Clone the disk
    qemu-img convert -f qcow2 -O qcow2 "$SOURCE_DISK" "$disk_path"
    
    log_success "Disk cloned for $vm_name"
}

# Create VM from cloned disk
create_vm_from_clone() {
    local vm_name="$1"
    local vm_config="$2"
    
    # Parse configuration
    IFS=':' read -r vm_ip cpu memory storage <<< "$vm_config"
    
    log_info "Creating VM: $vm_name ($vm_ip) - ${cpu}c/${memory}GB/${storage}GB"
    
    # Create VM disk path
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    
    # Resize disk if needed
    if [[ $storage -ne 50 ]]; then
        log_info "Resizing disk to ${storage}GB..."
        qemu-img resize "$disk_path" "${storage}G"
    fi
    
    # Create VM XML
    local vm_xml="/tmp/${vm_name}.xml"
    
    cat > "$vm_xml" << VM_EOF
<domain type='kvm'>
  <name>$vm_name</name>
  <uuid>$(uuidgen)</uuid>
  <memory unit='KiB'>$((memory * 1024 * 1024))</memory>
  <currentMemory unit='KiB'>$((memory * 1024 * 1024))</currentMemory>
  <vcpu placement='static'>$cpu</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' cores='$cpu' threads='1'/>
    <feature policy='require' name='svm'/>
  </cpu>
  <clock offset='utc'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='writeback'/>
      <source file='$disk_path'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <channel type='unix'>
      <target type='virtio' name='org.qemu.guest_agent.0'/>
    </channel>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes' listen='0.0.0.0'/>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
    </video>
    <memballoon model='virtio'/>
  </devices>
</domain>
VM_EOF
    
    # Define and start the VM
    virsh define "$vm_xml"
    virsh start "$vm_name"
    
    rm "$vm_xml"
    
    log_success "VM $vm_name created and started"
}

# Main function
main() {
    log_info "Starting VM Cloning Process"
    log_info "==========================="
    log_info "Source VM: $SOURCE_VM"
    log_info "Total VMs to create: ${#VM_CONFIGS[@]}"
    
    # Create all VMs
    for vm_name in "${!VM_CONFIGS[@]}"; do
        local vm_config="${VM_CONFIGS[$vm_name]}"
        IFS=':' read -r vm_ip cpu memory storage <<< "$vm_config"
        
        clone_vm_disk "$vm_name"
        create_vm_from_clone "$vm_name" "$vm_config"
    done
    
    log_success "All VMs created!"
    log_info "VM List:"
    virsh list --all
    
    log_info "Next steps:"
    log_info "1. Wait for VMs to boot"
    log_info "2. Install K3s cluster on all VMs"
    log_info "3. Configure Longhorn storage"
    log_info "4. Set up MetalLB load balancer"
}

# Run main function
main "$@"
