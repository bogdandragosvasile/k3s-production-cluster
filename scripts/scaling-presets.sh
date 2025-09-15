#!/bin/bash

# K3s Cluster Scaling Presets
# Predefined configurations for different workload scenarios

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [PRESET] [OPTIONS]"
    echo ""
    echo "Available presets:"
    echo "  minimal        - Minimal cluster for development/testing (1 master, 1 worker)"
    echo "  development    - Development cluster (1 master, 2 workers, 1 storage)"
    echo "  staging        - Staging cluster (3 masters, 3 workers, 2 storage, 2 LB)"
    echo "  production     - Production cluster (3 masters, 6 workers, 2 storage, 2 LB)"
    echo "  high-load      - High load cluster (5 masters, 12 workers, 3 storage, 2 LB)"
    echo "  gpu-enabled    - GPU-enabled cluster (3 masters, 4 workers, 2 storage, 2 LB, 2 GPU)"
    echo "  cost-optimized - Cost-optimized cluster (1 master, 3 workers, 1 storage)"
    echo "  ha-minimal     - HA minimal cluster (3 masters, 2 workers, 2 storage, 2 LB)"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (development, staging, production) [default: development]"
    echo "  -c, --cluster-name NAME  Cluster name [default: k3s]"
    echo "  --dry-run                Show what would be changed without applying"
    echo "  --force                  Force scaling even if cluster is not ready"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 minimal --environment development"
    echo "  $0 production --dry-run"
    echo "  $0 high-load --environment staging --cluster-name k3s-staging"
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

# Function to show preset configuration
show_preset_config() {
    local preset="$1"
    local masters="$2"
    local workers="$3"
    local storage="$4"
    local lb="$5"
    local gpu="$6"
    local description="$7"
    
    echo ""
    echo "Preset: $preset"
    echo "Description: $description"
    echo "Configuration:"
    echo "  Masters: $masters"
    echo "  Workers: $workers"
    echo "  Storage: $storage"
    echo "  Load Balancers: $lb"
    echo "  GPU Nodes: $gpu"
    echo "  Total Nodes: $((masters + workers + storage + lb + gpu))"
    echo ""
}

# Function to apply preset
apply_preset() {
    local preset="$1"
    local environment="$2"
    local cluster_name="$3"
    local dry_run="$4"
    local force="$5"
    
    case "$preset" in
        "minimal")
            show_preset_config "minimal" 1 1 0 0 0 "Minimal cluster for development/testing"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 1 \
                --workers 1 \
                --storage 0 \
                --loadbalancers 0 \
                --gpu 0 \
                $dry_run $force
            ;;
        "development")
            show_preset_config "development" 1 2 1 0 0 "Development cluster with basic storage"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 1 \
                --workers 2 \
                --storage 1 \
                --loadbalancers 0 \
                --gpu 0 \
                $dry_run $force
            ;;
        "staging")
            show_preset_config "staging" 3 3 2 2 0 "Staging cluster with HA and load balancing"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 3 \
                --workers 3 \
                --storage 2 \
                --loadbalancers 2 \
                --gpu 0 \
                $dry_run $force
            ;;
        "production")
            show_preset_config "production" 3 6 2 2 0 "Production cluster with HA and load balancing"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 3 \
                --workers 6 \
                --storage 2 \
                --loadbalancers 2 \
                --gpu 0 \
                $dry_run $force
            ;;
        "high-load")
            show_preset_config "high-load" 5 12 3 2 0 "High load cluster for intensive workloads"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 5 \
                --workers 12 \
                --storage 3 \
                --loadbalancers 2 \
                --gpu 0 \
                $dry_run $force
            ;;
        "gpu-enabled")
            show_preset_config "gpu-enabled" 3 4 2 2 2 "GPU-enabled cluster for ML/AI workloads"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 3 \
                --workers 4 \
                --storage 2 \
                --loadbalancers 2 \
                --gpu 2 \
                $dry_run $force
            ;;
        "cost-optimized")
            show_preset_config "cost-optimized" 1 3 1 0 0 "Cost-optimized cluster for budget-conscious deployments"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 1 \
                --workers 3 \
                --storage 1 \
                --loadbalancers 0 \
                --gpu 0 \
                $dry_run $force
            ;;
        "ha-minimal")
            show_preset_config "ha-minimal" 3 2 2 2 0 "HA minimal cluster with redundancy"
            ./scripts/scale-cluster.sh \
                --environment "$environment" \
                --cluster-name "$cluster_name" \
                --masters 3 \
                --workers 2 \
                --storage 2 \
                --loadbalancers 2 \
                --gpu 0 \
                $dry_run $force
            ;;
        *)
            log_error "Unknown preset: $preset"
            usage
            exit 1
            ;;
    esac
}

# Function to list all presets
list_presets() {
    echo "Available K3s Cluster Scaling Presets:"
    echo "======================================"
    echo ""
    echo "1. minimal        - Minimal cluster for development/testing"
    echo "   Masters: 1, Workers: 1, Storage: 0, LB: 0, GPU: 0"
    echo "   Use case: Local development, testing, CI/CD"
    echo ""
    echo "2. development    - Development cluster with basic storage"
    echo "   Masters: 1, Workers: 2, Storage: 1, LB: 0, GPU: 0"
    echo "   Use case: Development environment, feature testing"
    echo ""
    echo "3. staging        - Staging cluster with HA and load balancing"
    echo "   Masters: 3, Workers: 3, Storage: 2, LB: 2, GPU: 0"
    echo "   Use case: Pre-production testing, integration testing"
    echo ""
    echo "4. production     - Production cluster with HA and load balancing"
    echo "   Masters: 3, Workers: 6, Storage: 2, LB: 2, GPU: 0"
    echo "   Use case: Production workloads, customer-facing applications"
    echo ""
    echo "5. high-load      - High load cluster for intensive workloads"
    echo "   Masters: 5, Workers: 12, Storage: 3, LB: 2, GPU: 0"
    echo "   Use case: High-traffic applications, data processing"
    echo ""
    echo "6. gpu-enabled    - GPU-enabled cluster for ML/AI workloads"
    echo "   Masters: 3, Workers: 4, Storage: 2, LB: 2, GPU: 2"
    echo "   Use case: Machine learning, AI workloads, GPU computing"
    echo ""
    echo "7. cost-optimized - Cost-optimized cluster for budget-conscious deployments"
    echo "   Masters: 1, Workers: 3, Storage: 1, LB: 0, GPU: 0"
    echo "   Use case: Budget-constrained environments, small teams"
    echo ""
    echo "8. ha-minimal     - HA minimal cluster with redundancy"
    echo "   Masters: 3, Workers: 2, Storage: 2, LB: 2, GPU: 0"
    echo "   Use case: Small HA deployments, critical applications"
    echo ""
}

# Parse command line arguments
PRESET=""
ENVIRONMENT="development"
CLUSTER_NAME="k3s"
DRY_RUN=""
FORCE=""

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
        --dry-run)
            DRY_RUN="--dry-run"
            shift
            ;;
        --force)
            FORCE="--force"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        list)
            list_presets
            exit 0
            ;;
        *)
            if [[ -z "$PRESET" ]]; then
                PRESET="$1"
            else
                log_error "Unknown option: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if preset is provided
if [[ -z "$PRESET" ]]; then
    log_error "No preset specified"
    usage
    exit 1
fi

# Check if scale-cluster.sh exists
if [[ ! -f "scripts/scale-cluster.sh" ]]; then
    log_error "scale-cluster.sh not found. Please run this script from the project root."
    exit 1
fi

# Apply the preset
log "Applying preset: $PRESET"
apply_preset "$PRESET" "$ENVIRONMENT" "$CLUSTER_NAME" "$DRY_RUN" "$FORCE"
