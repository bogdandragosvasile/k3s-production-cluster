#!/bin/bash

# Quick K3s Cluster Scaling Commands
# Simple commands for common scaling operations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  up              Scale up cluster (more nodes)"
    echo "  down            Scale down cluster (fewer nodes)"
    echo "  status          Show current cluster status"
    echo "  presets         List available scaling presets"
    echo "  help            Show this help message"
    echo ""
    echo "Scale up options:"
    echo "  --workers N     Add N worker nodes"
    echo "  --masters N     Set master nodes to N"
    echo "  --storage N     Set storage nodes to N"
    echo "  --gpu N         Set GPU nodes to N"
    echo ""
    echo "Scale down options:"
    echo "  --workers N     Set worker nodes to N"
    echo "  --masters N     Set master nodes to N (minimum 1)"
    echo "  --storage N     Set storage nodes to N"
    echo "  --gpu N         Set GPU nodes to N"
    echo ""
    echo "Common options:"
    echo "  -e, --environment ENV    Environment (development, staging, production)"
    echo "  -c, --cluster-name NAME  Cluster name"
    echo "  --dry-run                Show what would be changed without applying"
    echo "  --force                  Force scaling even if cluster is not ready"
    echo ""
    echo "Examples:"
    echo "  $0 up --workers 5                    # Add 5 worker nodes"
    echo "  $0 down --workers 2                  # Scale down to 2 workers"
    echo "  $0 status                            # Show current status"
    echo "  $0 presets                           # List available presets"
    echo "  $0 up --workers 3 --dry-run          # Preview scaling up"
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

# Function to get current cluster state
get_current_state() {
    log "Getting current cluster state..."
    
    # Get current node counts from Terraform state
    if [[ -f "terraform/terraform.tfstate" ]]; then
        CURRENT_MASTERS=$(terraform -chdir="terraform" output -raw master_count 2>/dev/null || echo "0")
        CURRENT_WORKERS=$(terraform -chdir="terraform" output -raw worker_count 2>/dev/null || echo "0")
        CURRENT_STORAGE=$(terraform -chdir="terraform" output -raw storage_count 2>/dev/null || echo "0")
        CURRENT_LB=$(terraform -chdir="terraform" output -raw lb_count 2>/dev/null || echo "0")
        CURRENT_GPU=$(terraform -chdir="terraform" output -raw gpu_count 2>/dev/null || echo "0")
    else
        log_warning "No Terraform state found"
        CURRENT_MASTERS=0
        CURRENT_WORKERS=0
        CURRENT_STORAGE=0
        CURRENT_LB=0
        CURRENT_GPU=0
    fi
    
    # Get actual running nodes from Kubernetes
    if [[ -f "kubeconfig" ]] && KUBECONFIG="./kubeconfig" kubectl get nodes &>/dev/null; then
        ACTUAL_NODES=$(KUBECONFIG="./kubeconfig" kubectl get nodes --no-headers | wc -l)
        READY_NODES=$(KUBECONFIG="./kubeconfig" kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
        log "Current cluster: $ACTUAL_NODES total nodes, $READY_NODES ready"
    else
        log_warning "Cannot connect to Kubernetes cluster"
        ACTUAL_NODES=0
        READY_NODES=0
    fi
}

# Function to show cluster status
show_status() {
    echo ""
    echo "K3s Cluster Status"
    echo "=================="
    echo "Environment: $ENVIRONMENT"
    echo "Cluster: $CLUSTER_NAME"
    echo ""
    echo "Current Configuration:"
    echo "  Masters: $CURRENT_MASTERS"
    echo "  Workers: $CURRENT_WORKERS"
    echo "  Storage: $CURRENT_STORAGE"
    echo "  Load Balancers: $CURRENT_LB"
    echo "  GPU Nodes: $CURRENT_GPU"
    echo "  Total: $((CURRENT_MASTERS + CURRENT_WORKERS + CURRENT_STORAGE + CURRENT_LB + CURRENT_GPU))"
    echo ""
    
    if [[ $ACTUAL_NODES -gt 0 ]]; then
        echo "Running Nodes: $ACTUAL_NODES (Ready: $READY_NODES)"
        echo ""
        echo "Node Details:"
        KUBECONFIG="./kubeconfig" kubectl get nodes || echo "Cannot get node details"
    else
        echo "No running nodes detected"
    fi
}

# Function to calculate new counts for scale up
calculate_scale_up() {
    NEW_MASTERS=$CURRENT_MASTERS
    NEW_WORKERS=$CURRENT_WORKERS
    NEW_STORAGE=$CURRENT_STORAGE
    NEW_GPU=$CURRENT_GPU
    
    if [[ -n "${WORKERS:-}" ]]; then
        NEW_WORKERS=$WORKERS
    fi
    if [[ -n "${MASTERS:-}" ]]; then
        NEW_MASTERS=$MASTERS
    fi
    if [[ -n "${STORAGE:-}" ]]; then
        NEW_STORAGE=$STORAGE
    fi
    if [[ -n "${GPU:-}" ]]; then
        NEW_GPU=$GPU
    fi
}

# Function to calculate new counts for scale down
calculate_scale_down() {
    NEW_MASTERS=$CURRENT_MASTERS
    NEW_WORKERS=$CURRENT_WORKERS
    NEW_STORAGE=$CURRENT_STORAGE
    NEW_GPU=$CURRENT_GPU
    
    if [[ -n "${WORKERS:-}" ]]; then
        NEW_WORKERS=$WORKERS
    fi
    if [[ -n "${MASTERS:-}" ]]; then
        NEW_MASTERS=$MASTERS
    fi
    if [[ -n "${STORAGE:-}" ]]; then
        NEW_STORAGE=$STORAGE
    fi
    if [[ -n "${GPU:-}" ]]; then
        NEW_GPU=$GPU
    fi
}

# Function to validate scaling parameters
validate_scaling() {
    log "Validating scaling parameters..."
    
    # Validate master count (must be odd for HA)
    if [[ $NEW_MASTERS -gt 0 && $((NEW_MASTERS % 2)) -eq 0 ]]; then
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
    if [[ $NEW_MASTERS -lt 1 ]]; then
        log_error "At least 1 master node is required"
        exit 1
    fi
    
    if [[ $NEW_WORKERS -lt 0 ]]; then
        log_error "Worker count cannot be negative"
        exit 1
    fi
    
    if [[ $NEW_STORAGE -lt 0 ]]; then
        log_error "Storage count cannot be negative"
        exit 1
    fi
    
    if [[ $NEW_GPU -lt 0 ]]; then
        log_error "GPU count cannot be negative"
        exit 1
    fi
    
    log_success "Scaling parameters validated"
}

# Function to show scaling summary
show_scaling_summary() {
    echo ""
    echo "Scaling Summary"
    echo "==============="
    echo "Environment: $ENVIRONMENT"
    echo "Cluster: $CLUSTER_NAME"
    echo ""
    echo "Changes:"
    echo "  Masters: $CURRENT_MASTERS → $NEW_MASTERS"
    echo "  Workers: $CURRENT_WORKERS → $NEW_WORKERS"
    echo "  Storage: $CURRENT_STORAGE → $NEW_STORAGE"
    echo "  Load Balancers: $CURRENT_LB → $CURRENT_LB (unchanged)"
    echo "  GPU Nodes: $CURRENT_GPU → $NEW_GPU"
    echo ""
    echo "Total nodes: $((CURRENT_MASTERS + CURRENT_WORKERS + CURRENT_STORAGE + CURRENT_LB + CURRENT_GPU)) → $((NEW_MASTERS + NEW_WORKERS + NEW_STORAGE + CURRENT_LB + NEW_GPU))"
    echo ""
}

# Function to execute scaling
execute_scaling() {
    log "Executing cluster scaling..."
    
    # Build scale-cluster.sh command
    CMD="./scripts/scale-cluster.sh"
    CMD="$CMD --environment $ENVIRONMENT"
    CMD="$CMD --cluster-name $CLUSTER_NAME"
    CMD="$CMD --masters $NEW_MASTERS"
    CMD="$CMD --workers $NEW_WORKERS"
    CMD="$CMD --storage $NEW_STORAGE"
    CMD="$CMD --loadbalancers $CURRENT_LB"
    CMD="$CMD --gpu $NEW_GPU"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        CMD="$CMD --dry-run"
    fi
    
    if [[ "$FORCE" == "true" ]]; then
        CMD="$CMD --force"
    fi
    
    # Execute the command
    log "Running: $CMD"
    eval "$CMD"
}

# Parse command line arguments
COMMAND=""
ENVIRONMENT="development"
CLUSTER_NAME="k3s"
DRY_RUN="false"
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        up|down|status|presets|help)
            COMMAND="$1"
            shift
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --workers)
            WORKERS="$2"
            shift 2
            ;;
        --masters)
            MASTERS="$2"
            shift 2
            ;;
        --storage)
            STORAGE="$2"
            shift 2
            ;;
        --gpu)
            GPU="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
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

# Check if command is provided
if [[ -z "$COMMAND" ]]; then
    log_error "No command specified"
    usage
    exit 1
fi

# Check if scale-cluster.sh exists
if [[ ! -f "scripts/scale-cluster.sh" ]]; then
    log_error "scale-cluster.sh not found. Please run this script from the project root."
    exit 1
fi

# Execute command
case "$COMMAND" in
    "status")
        get_current_state
        show_status
        ;;
    "presets")
        ./scripts/scaling-presets.sh list
        ;;
    "up"|"down")
        get_current_state
        
        if [[ "$COMMAND" == "up" ]]; then
            calculate_scale_up
        else
            calculate_scale_down
        fi
        
        show_scaling_summary
        validate_scaling
        execute_scaling
        ;;
    "help")
        usage
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac
