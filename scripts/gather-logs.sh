#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Log Gathering
# Collects comprehensive logs from all cluster components

echo "📋 Gathering comprehensive cluster logs..."

# Colors for output
# # # RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
LOG_DIR="${LOG_DIR:-./cluster-logs}"
# # # TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to create log directory
create_log_directory() {
    echo "📁 Creating log directory: $LOG_DIR"
    mkdir -p "$LOG_DIR"
}

# Function to gather system logs
gather_system_logs() {
    echo "🔍 Gathering system logs..."
    
    # Host system logs
    echo "  📋 Host system logs"
    journalctl --since "1 hour ago" > "$LOG_DIR/host-system.log" 2>/dev/null || true
    
    # Libvirt logs
    echo "  📋 Libvirt logs"
    journalctl -u libvirtd --since "1 hour ago" > "$LOG_DIR/libvirt.log" 2>/dev/null || true
    
    # QEMU logs
    echo "  📋 QEMU logs"
    journalctl -u qemu --since "1 hour ago" > "$LOG_DIR/qemu.log" 2>/dev/null || true
}

# Function to gather VM logs
gather_vm_logs() {
    local inventory_file="${1:-ansible/inventory.yml}"
    
    echo "🔍 Gathering VM logs..."
    
    if [[ ! -f "$inventory_file" ]]; then
        echo -e "${YELLOW}⚠️  Inventory file not found: $inventory_file${NC}"
        return 1
    fi
    
    # Get all VM IPs
    local all_ips
    all_ips=$(ansible all -i "$inventory_file" --list-hosts | grep -v "hosts" | tr -d ' ' | tr '\n' ' ')
    
    for ip in $all_ips; do
        if [[ -n "$ip" ]]; then
            echo "  📋 Gathering logs from $ip"
            local vm_log_dir="$LOG_DIR/vm-$ip"
            mkdir -p "$vm_log_dir"
            
            # System logs
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "sudo journalctl --since '1 hour ago'" > "$vm_log_dir/system.log" 2>/dev/null || true
            
            # K3s logs
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "sudo journalctl -u k3s --since '1 hour ago'" > "$vm_log_dir/k3s.log" 2>/dev/null || true
            
            # Docker logs (if available)
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "sudo docker logs \$(sudo docker ps -q) 2>/dev/null" > "$vm_log_dir/docker.log" 2>/dev/null || true
            
            # Network configuration
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "ip addr show" > "$vm_log_dir/network.log" 2>/dev/null || true
            
            # Disk usage
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "df -h" > "$vm_log_dir/disk.log" 2>/dev/null || true
            
            # Memory usage
            ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$ip" "free -h" > "$vm_log_dir/memory.log" 2>/dev/null || true
        fi
    done
}

# Function to gather Kubernetes logs
gather_k8s_logs() {
    local kubeconfig="${1:-./kubeconfig}"
    
    echo "🔍 Gathering Kubernetes logs..."
    
    if [[ ! -f "$kubeconfig" ]]; then
        echo -e "${YELLOW}⚠️  Kubeconfig not found: $kubeconfig${NC}"
        return 1
    fi
    
    export KUBECONFIG="$kubeconfig"
    
    # Cluster info
    echo "  📋 Cluster information"
    kubectl cluster-info > "$LOG_DIR/cluster-info.log" 2>&1 || true
    
    # Nodes
    echo "  📋 Node information"
    kubectl get nodes -o wide > "$LOG_DIR/nodes.log" 2>&1 || true
    
    # Pods
    echo "  �� Pod information"
    kubectl get pods -A -o wide > "$LOG_DIR/pods.log" 2>&1 || true
    
    # Services
    echo "  📋 Service information"
    kubectl get svc -A > "$LOG_DIR/services.log" 2>&1 || true
    
    # Events
    echo "  📋 Events"
    kubectl get events -A --sort-by='.lastTimestamp' > "$LOG_DIR/events.log" 2>&1 || true
    
    # Pod logs
    echo "  📋 Pod logs"
    local pod_log_dir="$LOG_DIR/pod-logs"
    mkdir -p "$pod_log_dir"
    
    for pod in $(kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null || true); do
        if [[ -n "$pod" ]]; then
            local namespace
            namespace=$(echo "$pod" | cut -d'/' -f1)
            local pod_name
            pod_name=$(echo "$pod" | cut -d'/' -f2)
            echo "    📋 $namespace/$pod_name"
            kubectl logs -n "$namespace" "$pod_name" > "$pod_log_dir/${namespace}-${pod_name}.log" 2>&1 || true
        fi
    done
}

# Function to gather Terraform logs
gather_terraform_logs() {
    echo "🔍 Gathering Terraform logs..."
    
    if [[ -d "terraform" ]]; then
        echo "  📋 Terraform state"
        cp terraform/terraform.tfstate "$LOG_DIR/terraform.tfstate" 2>/dev/null || true
        cp terraform/terraform.tfstate.backup "$LOG_DIR/terraform.tfstate.backup" 2>/dev/null || true
        
        echo "  📋 Terraform plan log"
        cp terraform/terraform-plan.log "$LOG_DIR/terraform-plan.log" 2>/dev/null || true
        
        echo "  📋 Terraform apply log"
        cp terraform/terraform-apply.log "$LOG_DIR/terraform-apply.log" 2>/dev/null || true
    fi
}

# Function to gather Ansible logs
gather_ansible_logs() {
    echo "🔍 Gathering Ansible logs..."
    
    if [[ -f "ansible/inventory.yml" ]]; then
        echo "  📋 Ansible inventory"
        cp ansible/inventory.yml "$LOG_DIR/ansible-inventory.yml" 2>/dev/null || true
    fi
}

# Function to create summary report
create_summary_report() {
    echo "📋 Creating summary report..."
    
    cat > "$LOG_DIR/summary.md" << 'SUMMARY_EOF'
# K3s Production Cluster - Log Summary

**Generated:** $(date)
**Timestamp:** $TIMESTAMP

## Cluster Status

### Nodes
```
$(kubectl get nodes -o wide 2>/dev/null || echo "Kubernetes not available")
```

### Pods
```
$(kubectl get pods -A 2>/dev/null || echo "Kubernetes not available")
```

### Services
```
$(kubectl get svc -A 2>/dev/null || echo "Kubernetes not available")
```

## Log Files

- `host-system.log` - Host system logs
- `libvirt.log` - Libvirt daemon logs
- `qemu.log` - QEMU logs
- `vm-*/system.log` - VM system logs
- `vm-*/k3s.log` - K3s service logs
- `vm-*/network.log` - VM network configuration
- `vm-*/disk.log` - VM disk usage
- `vm-*/memory.log` - VM memory usage
- `cluster-info.log` - Kubernetes cluster info
- `nodes.log` - Kubernetes nodes
- `pods.log` - Kubernetes pods
- `services.log` - Kubernetes services
- `events.log` - Kubernetes events
- `pod-logs/*.log` - Individual pod logs
- `terraform.tfstate` - Terraform state
- `terraform-plan.log` - Terraform plan output
- `terraform-apply.log` - Terraform apply output
- `ansible-inventory.yml` - Ansible inventory

## Troubleshooting

1. Check system logs for host-level issues
2. Check VM logs for VM-specific issues
3. Check Kubernetes logs for cluster issues
4. Check Terraform logs for infrastructure issues
5. Check Ansible logs for configuration issues

SUMMARY_EOF
}

# Main logic
echo "🚀 Starting log gathering process..."

# Create log directory
create_log_directory

# Gather system logs
gather_system_logs

# Gather VM logs (if inventory available)
if [[ -f "ansible/inventory.yml" ]]; then
    gather_vm_logs "ansible/inventory.yml"
fi

# Gather Kubernetes logs (if kubeconfig available)
if [[ -f "kubeconfig" ]]; then
    gather_k8s_logs "kubeconfig"
fi

# Gather Terraform logs
gather_terraform_logs

# Gather Ansible logs
gather_ansible_logs

# Create summary report
create_summary_report

echo -e "${GREEN}✅ Log gathering completed!${NC}"
echo "📁 Logs saved to: $LOG_DIR"
echo "📋 Summary report: $LOG_DIR/summary.md"
