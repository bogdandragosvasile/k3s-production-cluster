#!/bin/bash

# Setup kubectl access via HA Load Balancers
# Configures load balancers to expose Kubernetes API server

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KUBECONFIG_PATH="./kubeconfig"
LB1_IP="192.168.122.41"
LB2_IP="192.168.122.42"
MASTER1_IP="192.168.122.11"
MASTER2_IP="192.168.122.12"
MASTER3_IP="192.168.122.13"
KUBERNETES_PORT="6443"
SSH_USER="ubuntu"
SSH_KEY="~/.ssh/id_rsa"

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

# Check prerequisites
log "Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if kubeconfig exists
if [[ ! -f "$KUBECONFIG_PATH" ]]; then
    log_error "Kubeconfig not found at $KUBECONFIG_PATH"
    exit 1
fi

# Check if cluster is accessible
if ! KUBECONFIG="$KUBECONFIG_PATH" kubectl get nodes &>/dev/null; then
    log_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

log_success "Prerequisites check passed"

# Install HAProxy on load balancers
log "Installing HAProxy on load balancers..."

# Install on LB1
log "Installing HAProxy on LB1 ($LB1_IP)..."
ssh -o StrictHostKeyChecking=no -i "${SSH_KEY}" "${SSH_USER}@${LB1_IP}" << 'EOF'
    sudo apt update
    sudo apt install -y haproxy
    sudo systemctl enable haproxy
    sudo systemctl start haproxy
