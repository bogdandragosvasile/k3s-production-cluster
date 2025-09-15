#!/bin/bash

# K3s Cluster Scaling Script
# Allows dynamic scaling of master and worker nodes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="development"
CLUSTER_NAME="k3s"
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"
KUBECONFIG_PATH="./kubeconfig"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (development, staging, production) [default: development]"
    echo "  -c, --cluster-name NAME  Cluster name [default: k3s]"
    echo "  -m, --masters COUNT      Number of master nodes [default: 3]"
    echo "  -w, --workers COUNT      Number of worker nodes [default: 3]"
    echo "  -s, --storage COUNT      Number of storage nodes [default: 2]"
    echo "  -l, --loadbalancers COUNT Number of load balancer nodes [default: 2]"
    echo "  -g, --gpu COUNT          Number of GPU nodes [default: 0]"
    echo "  --dry-run                Show what would be changed without applying"
    echo "  --force                  Force scaling even if cluster is not ready"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --masters 1 --workers 2                    # Scale down for low workload"
    echo "  $0 --masters 5 --workers 10                   # Scale up for high workload"
    echo "  $0 --environment production --workers 8       # Scale production workers"
    echo "  $0 --dry-run --masters 1 --workers 2          # Preview changes"
}

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if terraform is available
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed or not in PATH"
        exit 1
    fi
    
    # Check if ansible is available
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if kubeconfig exists
    if [[ ! -f "$KUBECONFIG_PATH" ]]; then
        log_warning "Kubeconfig not found at $KUBECONFIG_PATH"
        log "Attempting to download kubeconfig..."
        if [[ -f "scripts/fix-kubeconfig.sh" ]]; then
            bash scripts/fix-kubeconfig.sh
        else
            log_error "Cannot find kubeconfig and fix script not available"
            exit 1
        fi
    fi
    
    log_success "Prerequisites check passed"
}

# Function to get current cluster state
get_current_state() {
    log "Getting current cluster state..."
    
    # Get current node counts from Terraform state
    if [[ -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
        CURRENT_MASTERS=$(terraform -chdir="$TERRAFORM_DIR" output -raw master_count 2>/dev/null || echo "0")
        CURRENT_WORKERS=$(terraform -chdir="$TERRAFORM_DIR" output -raw worker_count 2>/dev/null || echo "0")
        CURRENT_STORAGE=$(terraform -chdir="$TERRAFORM_DIR" output -raw storage_count 2>/dev/null || echo "0")
        CURRENT_LB=$(terraform -chdir="$TERRAFORM_DIR" output -raw lb_count 2>/dev/null || echo "0")
        CURRENT_GPU=$(terraform -chdir="$TERRAFORM_DIR" output -raw gpu_count 2>/dev/null || echo "0")
    else
        log_warning "No Terraform state found, assuming fresh deployment"
        CURRENT_MASTERS=0
        CURRENT_WORKERS=0
        CURRENT_STORAGE=0
        CURRENT_LB=0
        CURRENT_GPU=0
    fi
    
    # Get actual running nodes from Kubernetes
    if KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes &>/dev/null; then
        ACTUAL_NODES=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes --no-headers | wc -l)
        log "Current cluster has $ACTUAL_NODES running nodes"
    else
        log_warning "Cannot connect to Kubernetes cluster"
        ACTUAL_NODES=0
    fi
    
    log "Current state: Masters=$CURRENT_MASTERS, Workers=$CURRENT_WORKERS, Storage=$CURRENT_STORAGE, LB=$CURRENT_LB, GPU=$CURRENT_GPU"
}

# Function to validate scaling parameters
validate_scaling() {
    log "Validating scaling parameters..."
    
    # Validate master count (must be odd for HA)
    if [[ $MASTER_COUNT -gt 0 && $((MASTER_COUNT % 2)) -eq 0 ]]; then
        log_warning "Master count should be odd for HA (recommended: 1, 3, 5)"
        if [[ "$FORCE" != "true" ]]; then
            read -p "Continue with even number of masters? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Scaling cancelled"
                exit 1
            fi
        fi
    fi
    
    # Validate minimum counts
    if [[ $MASTER_COUNT -lt 1 ]]; then
        log_error "At least 1 master node is required"
        exit 1
    fi
    
    if [[ $WORKER_COUNT -lt 0 ]]; then
        log_error "Worker count cannot be negative"
        exit 1
    fi
    
    # Validate storage count
    if [[ $STORAGE_COUNT -lt 0 ]]; then
        log_error "Storage count cannot be negative"
        exit 1
    fi
    
    # Validate load balancer count
    if [[ $LB_COUNT -lt 0 ]]; then
        log_error "Load balancer count cannot be negative"
        exit 1
    fi
    
    # Validate GPU count
    if [[ $GPU_COUNT -lt 0 ]]; then
        log_error "GPU count cannot be negative"
        exit 1
    fi
    
    log_success "Scaling parameters validated"
}

# Function to create terraform.tfvars
create_tfvars() {
    log "Creating terraform.tfvars for scaling..."
    
    cat > "$TERRAFORM_DIR/terraform.tfvars" << TFVARS_EOF
# K3s Cluster Configuration - Generated by scale-cluster.sh
environment = "$ENVIRONMENT"
cluster_name = "$CLUSTER_NAME"

# Node counts
master_count = $MASTER_COUNT
worker_count = $WORKER_COUNT
storage_count = $STORAGE_COUNT
lb_count = $LB_COUNT
gpu_count = $GPU_COUNT

# Network configuration
network_cidr = "192.168.122.0/24"

# K3s configuration
k3s_version = "v1.33.4+k3s1"
k3s_token = ""

# Longhorn configuration
longhorn_version = "v1.7.2"

# MetalLB configuration
metallb_version = "v0.14.5"
metallb_ip_range = "192.168.122.100-192.168.122.150"
TFVARS_EOF
    
    log_success "terraform.tfvars created"
}

# Function to apply Terraform changes
apply_terraform() {
    log "Applying Terraform changes..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init -upgrade
    
    # Plan changes
    log "Planning Terraform changes..."
    terraform plan -out=scale.tfplan
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would apply the following changes:"
        terraform show scale.tfplan
        rm -f scale.tfplan
        cd ..
        return 0
    fi
    
    # Apply changes
    log "Applying Terraform changes..."
    terraform apply scale.tfplan
    rm -f scale.tfplan
    
    cd ..
    log_success "Terraform changes applied"
}

# Function to update Ansible inventory
update_inventory() {
    log "Updating Ansible inventory..."
    
    # Generate new inventory from Terraform
    cd "$TERRAFORM_DIR"
    terraform output -raw inventory > "../$ANSIBLE_DIR/inventory.yml"
    cd ..
    
    log_success "Ansible inventory updated"
}

# Function to run Ansible playbook
run_ansible() {
    log "Running Ansible playbook..."
    
    cd "$ANSIBLE_DIR"
    
    # Run the K3s installation playbook
    ansible-playbook -i inventory.yml playbooks/install-k3s.yaml \
        --extra-vars "environment=$ENVIRONMENT" \
        --extra-vars "cluster_name=$CLUSTER_NAME" \
        -v
    
    cd ..
    log_success "Ansible playbook completed"
}

# Function to verify cluster health
verify_cluster() {
    log "Verifying cluster health..."
    
    # Wait for nodes to be ready
    log "Waiting for nodes to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local ready_nodes=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
        local total_nodes=$(KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes --no-headers | wc -l)
        
        if [[ $ready_nodes -eq $total_nodes && $total_nodes -gt 0 ]]; then
            log_success "All $total_nodes nodes are ready"
            break
        fi
        
        log "Attempt $attempt/$max_attempts: $ready_nodes/$total_nodes nodes ready"
        sleep 10
        ((attempt++))
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Cluster verification timeout"
        return 1
    fi
    
    # Show cluster status
    log "Cluster status:"
    KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes
    KUBECONFIG="$KUBECONFIG_PATH" kubectl get pods -A
    
    log_success "Cluster verification completed"
}

# Function to show scaling summary
show_summary() {
    log "Scaling Summary:"
    echo "=================="
    echo "Environment: $ENVIRONMENT"
    echo "Cluster: $CLUSTER_NAME"
    echo "Masters: $CURRENT_MASTERS → $MASTER_COUNT"
    echo "Workers: $CURRENT_WORKERS → $WORKER_COUNT"
    echo "Storage: $CURRENT_STORAGE → $STORAGE_COUNT"
    echo "Load Balancers: $CURRENT_LB → $LB_COUNT"
    echo "GPU Nodes: $CURRENT_GPU → $GPU_COUNT"
    echo "=================="
}

# Parse command line arguments
MASTER_COUNT=3
WORKER_COUNT=3
STORAGE_COUNT=2
LB_COUNT=2
GPU_COUNT=0
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -m|--masters)
            MASTER_COUNT="$2"
            shift 2
            ;;
        -w|--workers)
            WORKER_COUNT="$2"
            shift 2
            ;;
        -s|--storage)
            STORAGE_COUNT="$2"
            shift 2
            ;;
        -l|--loadbalancers)
            LB_COUNT="$2"
            shift 2
            ;;
        -g|--gpu)
            GPU_COUNT="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log "Starting K3s cluster scaling..."
    
    # Get current state
    get_current_state
    
    # Show scaling summary
    show_summary
    
    # Validate scaling parameters
    validate_scaling
    
    # Check prerequisites
    check_prerequisites
    
    # Create terraform.tfvars
    create_tfvars
    
    # Apply Terraform changes
    apply_terraform
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run completed. No changes were applied."
        exit 0
    fi
    
    # Update Ansible inventory
    update_inventory
    
    # Run Ansible playbook
    run_ansible
    
    # Verify cluster health
    verify_cluster
    
    log_success "Cluster scaling completed successfully!"
    log "New cluster configuration:"
    KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes
}

# Run main function
main "$@"
