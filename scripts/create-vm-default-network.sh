#!/bin/bash

# VM Creation Script using default network
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

# Download Ubuntu ISO
download_ubuntu_iso() {
    log_info "Downloading Ubuntu 24.04 LTS ISO..."
    
    local iso_path="/var/lib/libvirt/images/ubuntu-24.04-server-amd64.iso"
    
    if [[ -f "$iso_path" ]]; then
        log_info "Ubuntu ISO already exists, skipping download"
        return
    fi
    
    local iso_url="https://releases.ubuntu.com/24.04/ubuntu-24.04.3-server-amd64.iso"
    
    log_info "Downloading from $iso_url..."
    wget -O "$iso_path" "$iso_url" || {
        log_error "Failed to download Ubuntu ISO"
        exit 1
    }
    
    log_success "Ubuntu ISO downloaded successfully"
}

# Create a test VM
create_test_vm() {
    log_info "Creating test VM: k3s-master-1"
    
    local vm_name="k3s-master-1"
    local cpu=4
    local memory=8
    local storage=50
    
    # Create VM disk
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    qemu-img create -f qcow2 "$disk_path" "${storage}G"
    
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
    <boot dev='cdrom'/>
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
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/var/lib/libvirt/images/ubuntu-24.04-server-amd64.iso'/>
      <target dev='hda' bus='ide'/>
      <readonly/>
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
    
    # Get VNC display info
    local vnc_display=$(virsh vncdisplay "$vm_name")
    log_info "VNC access: $vnc_display"
    log_info "You can connect via VNC viewer to: $(hostname -I | awk '{print $1}'):$vnc_display"
}

# Main function
main() {
    log_info "Starting VM Creation with Default Network"
    log_info "========================================="
    
    download_ubuntu_iso
    create_test_vm
    
    log_success "Test VM created successfully!"
    log_info "Next steps:"
    log_info "1. Connect via VNC to install Ubuntu"
    log_info "2. Configure networking and SSH"
    log_info "3. Install K3s"
    log_info "4. Repeat for other VMs"
}

# Run main function
main "$@"
