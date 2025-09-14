#!/bin/bash

# K3s Production Cluster Deployment Script
# This script deploys a complete K3s cluster on KVM VMs

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/configs/cluster-config.yaml"

# Logging
LOG_FILE="/var/log/k3s-deployment.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        exit 1
    fi
    
    # Check if libvirt is running
    if ! systemctl is-active --quiet libvirtd; then
        log_error "Libvirt is not running. Please start it first."
        exit 1
    fi
    
    # Check if KVM is available
    if ! kvm-ok >/dev/null 2>&1; then
        log_error "KVM is not available on this system"
        exit 1
    fi
    
    # Check available resources
    local available_mem=$(free -g | awk '/^Mem:/ {print $7}')
    local available_cores=$(nproc)
    
    if [[ $available_mem -lt 80 ]]; then
        log_warning "Available memory ($available_mem GB) is less than recommended (80 GB)"
    fi
    
    if [[ $available_cores -lt 120 ]]; then
        log_warning "Available CPU cores ($available_cores) is less than recommended (120)"
    fi
    
    log_success "Prerequisites check completed"
}

download_ubuntu_iso() {
    log_info "Downloading Ubuntu 24.04 LTS ISO..."
    
    local iso_path="/var/lib/libvirt/images/ubuntu-24.04-server-amd64.iso"
    
    if [[ -f "$iso_path" ]]; then
        log_info "Ubuntu ISO already exists, skipping download"
        return
    fi
    
    local iso_url="https://releases.ubuntu.com/24.04/ubuntu-24.04.3-server-amd64.iso"
    local checksum_url="https://releases.ubuntu.com/24.04/SHA256SUMS"
    
    log_info "Downloading from $iso_url..."
    wget -O "$iso_path" "$iso_url" || {
        log_error "Failed to download Ubuntu ISO"
        exit 1
    }
    
    log_success "Ubuntu ISO downloaded successfully"
}

create_vm_template() {
    log_info "Creating VM template..."
    
    local template_path="/var/lib/libvirt/images/ubuntu-24.04-template.qcow2"
    
    if [[ -f "$template_path" ]]; then
        log_info "VM template already exists, skipping creation"
        return
    fi
    
    # Create a 20GB template disk
    qemu-img create -f qcow2 "$template_path" 20G
    
    # Copy the template XML
    cp "$PROJECT_DIR/vm-templates/ubuntu-24.04-template.xml" /tmp/
    
    # Define the template VM
    virsh define /tmp/ubuntu-24.04-template.xml
    
    log_info "Starting template VM for installation..."
    virsh start ubuntu-24.04-template
    
    log_warning "Please complete the Ubuntu installation manually via VNC"
    log_warning "VNC connection: vncviewer localhost:$(virsh vncdisplay ubuntu-24.04-template)"
    log_warning "After installation, shut down the VM and press Enter to continue..."
    read -p "Press Enter when installation is complete and VM is shut down..."
    
    # Undefine the template VM
    virsh undefine ubuntu-24.04-template
    
    log_success "VM template created successfully"
}

create_vm_network() {
    log_info "Creating K3s network..."
    
    local network_xml="/tmp/k3s-network.xml"
    
    cat > "$network_xml" << EOF
<network>
  <name>k3s-network</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='k3s-br0' stp='on' delay='0'/>
  <ip address='192.168.1.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.1.100' end='192.168.1.199'/>
    </dhcp>
  </ip>
</network>
EOF
    
    # Create the network
    virsh net-define "$network_xml"
    virsh net-start k3s-network
    virsh net-autostart k3s-network
    
    rm "$network_xml"
    
    log_success "K3s network created successfully"
}

create_vm() {
    local vm_name="$1"
    local vm_type="$2"
    local cpu="$3"
    local memory="$4"
    local storage="$5"
    local ip="$6"
    
    log_info "Creating VM: $vm_name"
    
    # Create VM disk
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-24.04-template.qcow2 "$disk_path" "${storage}G"
    
    # Create VM XML
    local vm_xml="/tmp/${vm_name}.xml"
    
    cat > "$vm_xml" << EOF
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
      <source network='k3s-network'/>
      <model type='virtio'/>
      <ip address='$ip' prefix='24'/>
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
EOF
    
    # Define and start the VM
    virsh define "$vm_xml"
    virsh start "$vm_name"
    
    rm "$vm_xml"
    
    log_success "VM $vm_name created and started"
}

deploy_control_plane() {
    log_info "Deploying control plane VMs..."
    
    for i in {1..3}; do
        create_vm "k3s-master-$i" "master" 4 8 50 "192.168.1.1$i"
    done
    
    log_success "Control plane VMs deployed"
}

deploy_worker_nodes() {
    log_info "Deploying worker node VMs..."
    
    for i in {1..7}; do
        create_vm "k3s-worker-$i" "worker" 8 16 100 "192.168.1.2$i"
    done
    
    log_success "Worker node VMs deployed"
}

deploy_storage_nodes() {
    log_info "Deploying storage VMs..."
    
    for i in {1..2}; do
        create_vm "k3s-storage-$i" "storage" 4 8 200 "192.168.1.3$i"
    done
    
    log_success "Storage VMs deployed"
}

deploy_load_balancers() {
    log_info "Deploying load balancer VMs..."
    
    for i in {1..2}; do
        create_vm "k3s-lb-$i" "lb" 2 4 20 "192.168.1.4$i"
    done
    
    log_success "Load balancer VMs deployed"
}

deploy_gpu_node() {
    log_info "Deploying GPU node VM..."
    
    # Create GPU node with GPU passthrough
    local vm_name="k3s-gpu-1"
    local disk_path="/var/lib/libvirt/images/${vm_name}.qcow2"
    
    qemu-img create -f qcow2 -b /var/lib/libvirt/images/ubuntu-24.04-template.qcow2 "$disk_path" 100G
    
    local vm_xml="/tmp/${vm_name}.xml"
    
    cat > "$vm_xml" << EOF
<domain type='kvm'>
  <name>$vm_name</name>
  <uuid>$(uuidgen)</uuid>
  <memory unit='KiB'>25165824</memory>
  <currentMemory unit='KiB'>25165824</currentMemory>
  <vcpu placement='static'>12</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-8.2'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode='host-passthrough' check='none'>
    <topology sockets='1' cores='12' threads='1'/>
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
      <source network='k3s-network'/>
      <model type='virtio'/>
      <ip address='192.168.1.50' prefix='24'/>
    </interface>
    <!-- GPU Passthrough -->
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x03' slot='0x00' function='0x0'/>
      </source>
      <address type='pci' domain='0x0000' bus='0x06' slot='0x00' function='0x0'/>
    </hostdev>
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
EOF
    
    virsh define "$vm_xml"
    virsh start "$vm_name"
    
    rm "$vm_xml"
    
    log_success "GPU node VM deployed"
}

wait_for_vms() {
    log_info "Waiting for VMs to start..."
    
    local vms=(
        "k3s-master-1" "k3s-master-2" "k3s-master-3"
        "k3s-worker-1" "k3s-worker-2" "k3s-worker-3" "k3s-worker-4"
        "k3s-worker-5" "k3s-worker-6" "k3s-worker-7"
        "k3s-storage-1" "k3s-storage-2"
        "k3s-lb-1" "k3s-lb-2"
        "k3s-gpu-1"
    )
    
    for vm in "${vms[@]}"; do
        log_info "Waiting for $vm to be ready..."
        while ! virsh domstate "$vm" | grep -q "running"; do
            sleep 5
        done
        log_success "$vm is running"
    done
}

main() {
    log_info "Starting K3s Production Cluster Deployment"
    log_info "============================================="
    
    check_prerequisites
    download_ubuntu_iso
    create_vm_template
    create_vm_network
    
    deploy_control_plane
    deploy_worker_nodes
    deploy_storage_nodes
    deploy_load_balancers
    deploy_gpu_node
    
    wait_for_vms
    
    log_success "K3s Production Cluster Deployment Completed!"
    log_info "Next steps:"
    log_info "1. Complete Ubuntu installation on all VMs"
    log_info "2. Run: ./scripts/setup-k3s-cluster.sh"
    log_info "3. Run: ./scripts/setup-longhorn.sh"
    log_info "4. Run: ./scripts/setup-metallb.sh"
    
    log_info "VM List:"
    virsh list --all
}

# Run main function
main "$@"
