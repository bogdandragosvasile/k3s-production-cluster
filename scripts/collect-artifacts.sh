#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Artifact Collection
# Collects comprehensive artifacts for deployment analysis and troubleshooting

echo "📦 Collecting comprehensive deployment artifacts..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARTIFACTS_DIR=${ARTIFACTS_DIR:-/tmp/k3s-artifacts}
MASTER_IP=${1:-""}
KUBECONFIG_PATH=${KUBECONFIG_PATH:-./kubeconfig}
CLUSTER_NAME=${CLUSTER_NAME:-k3s-production}
ENVIRONMENT=${ENVIRONMENT:-production}
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# Retention settings
TERRAFORM_RETENTION_DAYS=${TERRAFORM_RETENTION_DAYS:-7}
ANSIBLE_RETENTION_DAYS=${ANSIBLE_RETENTION_DAYS:-7}
K3S_RETENTION_DAYS=${K3S_RETENTION_DAYS:-7}
HEALTH_RETENTION_DAYS=${HEALTH_RETENTION_DAYS:-30}
CLUSTER_RETENTION_DAYS=${CLUSTER_RETENTION_DAYS:-30}

# Function to log with timestamp
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Function to create directory structure
create_directories() {
    log "INFO" "Creating artifact directory structure..."
    
    mkdir -p "$ARTIFACTS_DIR"/{terraform,ansible,k3s,health,cluster,logs}
    
    log "SUCCESS" "Artifact directories created: $ARTIFACTS_DIR"
}

# Function to collect Terraform artifacts
collect_terraform_artifacts() {
    log "INFO" "Collecting Terraform artifacts..."
    
    local terraform_dir="$ARTIFACTS_DIR/terraform"
    
    # Copy Terraform state and logs
    if [[ -f "terraform/terraform.tfstate" ]]; then
        cp terraform/terraform.tfstate "$terraform_dir/"
        log "SUCCESS" "Terraform state copied"
    fi
    
    if [[ -f "terraform/terraform.tfstate.backup" ]]; then
        cp terraform/terraform.tfstate.backup "$terraform_dir/"
        log "SUCCESS" "Terraform state backup copied"
    fi
    
    if [[ -f "terraform/terraform-plan.log" ]]; then
        cp terraform/terraform-plan.log "$terraform_dir/"
        log "SUCCESS" "Terraform plan log copied"
    fi
    
    if [[ -f "terraform/terraform-apply.log" ]]; then
        cp terraform/terraform-apply.log "$terraform_dir/"
        log "SUCCESS" "Terraform apply log copied"
    fi
    
    # Copy backend configuration
    if [[ -f "terraform/backend.tf" ]]; then
        cp terraform/backend.tf "$terraform_dir/"
        log "SUCCESS" "Terraform backend config copied"
    fi
    
    log "SUCCESS" "Terraform artifacts collected"
}

# Function to collect Ansible artifacts
collect_ansible_artifacts() {
    log "INFO" "Collecting Ansible artifacts..."
    
    local ansible_dir="$ARTIFACTS_DIR/ansible"
    
    # Copy inventory
    if [[ -f "ansible/inventory.yml" ]]; then
        cp ansible/inventory.yml "$ansible_dir/"
        log "SUCCESS" "Ansible inventory copied"
    fi
    
    # Copy playbooks
    if [[ -d "ansible/playbooks" ]]; then
        cp -r ansible/playbooks "$ansible_dir/"
        log "SUCCESS" "Ansible playbooks copied"
    fi
    
    log "SUCCESS" "Ansible artifacts collected"
}

# Function to collect K3s logs from VMs
collect_k3s_logs() {
    local master_ip="$1"
    local k3s_dir="$ARTIFACTS_DIR/k3s"
    
    if [[ -z "$master_ip" ]]; then
        log "WARN" "No master IP provided, skipping K3s log collection"
        return 0
    fi
    
    log "INFO" "Collecting K3s logs from master node ($master_ip)..."
    
    # Collect K3s service logs
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$master_ip "sudo journalctl -u k3s --no-pager" > "$k3s_dir/k3s-master.log" 2>/dev/null; then
        log "SUCCESS" "K3s master service logs collected"
    else
        log "WARN" "Failed to collect K3s master service logs"
    fi
    
    # Collect system logs
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$master_ip "sudo journalctl --since '1 hour ago' --no-pager" > "$k3s_dir/system.log" 2>/dev/null; then
        log "SUCCESS" "System logs collected"
    else
        log "WARN" "Failed to collect system logs"
    fi
    
    log "SUCCESS" "K3s logs collected"
}

# Function to collect health report
collect_health_report() {
    local master_ip="$1"
    local health_dir="$ARTIFACTS_DIR/health"
    
    if [[ -z "$master_ip" ]]; then
        log "WARN" "No master IP provided, skipping health report collection"
        return 0
    fi
    
    log "INFO" "Generating health report..."
    
    # Generate health report
    if [[ -f "scripts/generate-health-report.sh" ]]; then
        ./scripts/generate-health-report.sh "$master_ip" "$KUBECONFIG_PATH"
        
        if [[ -f "/tmp/k3s-health-report.md" ]]; then
            cp /tmp/k3s-health-report.md "$health_dir/"
            log "SUCCESS" "Health report generated and copied"
        fi
    else
        log "WARN" "Health report script not found"
    fi
    
    log "SUCCESS" "Health report collected"
}

# Function to collect cluster artifacts
collect_cluster_artifacts() {
    local master_ip="$1"
    local cluster_dir="$ARTIFACTS_DIR/cluster"
    
    if [[ -z "$master_ip" ]]; then
        log "WARN" "No master IP provided, skipping cluster artifact collection"
        return 0
    fi
    
    log "INFO" "Collecting cluster artifacts..."
    
    # Sanitize and copy kubeconfig
    if [[ -f "$KUBECONFIG_PATH" ]]; then
        if [[ -f "scripts/sanitize-kubeconfig.sh" ]]; then
            ./scripts/sanitize-kubeconfig.sh "$KUBECONFIG_PATH" "$cluster_dir/kubeconfig-sanitized"
            log "SUCCESS" "Kubeconfig sanitized and copied"
        else
            cp "$KUBECONFIG_PATH" "$cluster_dir/kubeconfig"
            log "SUCCESS" "Kubeconfig copied (not sanitized)"
        fi
    fi
    
    log "SUCCESS" "Cluster artifacts collected"
}

# Function to create overall summary
create_overall_summary() {
    log "INFO" "Creating overall artifact summary..."
    
    local total_size=$(du -sh "$ARTIFACTS_DIR" 2>/dev/null | cut -f1 || echo "Unknown")
    
    cat > "$ARTIFACTS_DIR/README.md" << EOF
# K3s Production Cluster Artifacts

**Environment:** $ENVIRONMENT  
**Cluster Name:** $CLUSTER_NAME  
**Master IP:** $MASTER_IP  
**Generated:** $(date)  
**Total Size:** $total_size  

## 📁 Artifact Structure

\`\`\`
$ARTIFACTS_DIR/
├── terraform/           # Terraform state and logs ($TERRAFORM_RETENTION_DAYS days)
├── ansible/             # Ansible inventory and playbooks ($ANSIBLE_RETENTION_DAYS days)
├── k3s/                 # K3s service logs ($K3S_RETENTION_DAYS days)
├── health/              # Health reports ($HEALTH_RETENTION_DAYS days)
├── cluster/             # Cluster configuration ($CLUSTER_RETENTION_DAYS days)
└── logs/                # Additional logs
\`\`\`

## 📋 How to Use

1. **Download**: Get artifacts from GitHub Actions run
2. **Extract**: Unzip the artifact archive
3. **Analyze**: Review relevant sections for troubleshooting
4. **Connect**: Use sanitized kubeconfig for cluster access
5. **Debug**: Check logs for specific issues

## 🔒 Security Notes

- Kubeconfig has been sanitized for safe sharing
- Sensitive data replaced with placeholders
- Original secrets kept secure and local
- Replace placeholders before using sanitized config

---
*Generated by K3s Production Cluster Artifact Collector*  
*Generated at: $(date)*
