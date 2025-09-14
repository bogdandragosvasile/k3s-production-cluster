#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Health Report Generator
# Generates comprehensive cluster health reports with sanitized output

echo "📋 Generating comprehensive K3s cluster health report..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPORT_FILE=${REPORT_FILE:-/tmp/k3s-health-report.md}
KUBECONFIG_PATH=${KUBECONFIG_PATH:-./kubeconfig}
CLUSTER_NAME=${CLUSTER_NAME:-k3s-production}
ENVIRONMENT=${ENVIRONMENT:-production}
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

# Function to log with timestamp
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl >/dev/null 2>&1; then
        log "ERROR" "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if [[ ! -f "$KUBECONFIG_PATH" ]]; then
        log "ERROR" "Kubeconfig not found at $KUBECONFIG_PATH"
        exit 1
    fi
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    log "INFO" "Using kubeconfig: $KUBECONFIG_PATH"
}

# Function to get cluster info with error handling
get_cluster_info() {
    local cmd="$1"
    local description="$2"
    local output=""
    
    log "INFO" "Collecting $description..."
    
    if output=$(eval "$cmd" 2>&1); then
        echo "$output"
    else
        log "WARN" "Failed to get $description: $output"
        echo "❌ Error retrieving $description"
    fi
}

# Function to check API server health
check_api_health() {
    local master_ip="$1"
    local health_status=""
    
    log "INFO" "Checking API server health..."
    
    # Check /readyz endpoint
    if health_status=$(curl -k -s -f "https://$master_ip:6443/readyz" 2>/dev/null); then
        echo "✅ API Server Ready: $health_status"
    else
        echo "❌ API Server Not Ready"
    fi
    
    # Check /healthz endpoint
    if health_status=$(curl -k -s -f "https://$master_ip:6443/healthz" 2>/dev/null); then
        echo "✅ API Server Healthy: $health_status"
    else
        echo "❌ API Server Unhealthy"
    fi
}

# Function to get node status summary
get_node_summary() {
    local total_nodes=0
    local ready_nodes=0
    local not_ready_nodes=0
    
    log "INFO" "Analyzing node status..."
    
    # Count total nodes
    total_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    
    # Count ready nodes
    ready_nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    
    # Count not ready nodes
    not_ready_nodes=$((total_nodes - ready_nodes))
    
    echo "📊 Node Summary:"
    echo "  Total Nodes: $total_nodes"
    echo "  Ready Nodes: $ready_nodes"
    echo "  Not Ready Nodes: $not_ready_nodes"
    
    if [[ $not_ready_nodes -gt 0 ]]; then
        echo "⚠️  Warning: $not_ready_nodes nodes are not ready"
        kubectl get nodes --no-headers | grep -v " Ready " | while read -r line; do
            echo "    - $line"
        done
    fi
}

# Function to get pod status summary
get_pod_summary() {
    local total_pods=0
    local running_pods=0
    local pending_pods=0
    local failed_pods=0
    
    log "INFO" "Analyzing pod status..."
    
    # Count total pods
    total_pods=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
    
    # Count running pods
    running_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Running " || echo "0")
    
    # Count pending pods
    pending_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Pending " || echo "0")
    
    # Count failed pods
    failed_pods=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c " Failed " || echo "0")
    
    echo "📊 Pod Summary:"
    echo "  Total Pods: $total_pods"
    echo "  Running Pods: $running_pods"
    echo "  Pending Pods: $pending_pods"
    echo "  Failed Pods: $failed_pods"
    
    if [[ $failed_pods -gt 0 ]]; then
        echo "⚠️  Warning: $failed_pods pods have failed"
        kubectl get pods -A --no-headers | grep " Failed " | while read -r line; do
            echo "    - $line"
        done
    fi
}

# Function to generate the health report
generate_health_report() {
    local master_ip="$1"
    
    log "INFO" "Generating comprehensive health report..."
    
    cat > "$REPORT_FILE" << EOF
# K3s Cluster Health Report

**Environment:** $ENVIRONMENT  
**Cluster Name:** $CLUSTER_NAME  
**Generated:** $TIMESTAMP  
**Master IP:** $master_ip  

## Executive Summary

$(get_node_summary)

$(get_pod_summary)

## Cluster Nodes

\`\`\`
$(get_cluster_info "kubectl get nodes -o wide" "cluster nodes")
\`\`\`

## All Pods

\`\`\`
$(get_cluster_info "kubectl get pods -A" "all pods")
\`\`\`

## All Services

\`\`\`
$(get_cluster_info "kubectl get svc -A" "all services")
\`\`\`

## API Server Health

\`\`\`
$(check_api_health "$master_ip")
\`\`\`

## Cluster Events

\`\`\`
$(get_cluster_info "kubectl get events --sort-by='.lastTimestamp' -A" "cluster events")
\`\`\`

## Persistent Volumes

\`\`\`
$(get_cluster_info "kubectl get pv" "persistent volumes")
\`\`\`

## Persistent Volume Claims

\`\`\`
$(get_cluster_info "kubectl get pvc -A" "persistent volume claims")
\`\`\`

## Storage Classes

\`\`\`
$(get_cluster_info "kubectl get storageclass" "storage classes")
\`\`\`

## Ingress Controllers

\`\`\`
$(get_cluster_info "kubectl get pods -A | grep -E '(ingress|traefik|nginx)'" "ingress controllers")
\`\`\`

## System Pods Status

\`\`\`
$(get_cluster_info "kubectl get pods -n kube-system" "system pods")
\`\`\`

## Node Resources

\`\`\`
$(get_cluster_info "kubectl top nodes 2>/dev/null || echo 'Metrics server not available'" "node resources")
\`\`\`

## Pod Resources

\`\`\`
$(get_cluster_info "kubectl top pods -A 2>/dev/null || echo 'Metrics server not available'" "pod resources")
\`\`\`

## Network Policies

\`\`\`
$(get_cluster_info "kubectl get networkpolicies -A" "network policies")
\`\`\`

## ConfigMaps

\`\`\`
$(get_cluster_info "kubectl get configmaps -A" "configmaps")
\`\`\`

## Secrets

\`\`\`
$(get_cluster_info "kubectl get secrets -A" "secrets")
\`\`\`

## Cluster Info

\`\`\`
$(get_cluster_info "kubectl cluster-info" "cluster info")
\`\`\`

## Version Information

\`\`\`
$(get_cluster_info "kubectl version --short" "version info")
\`\`\`

---
*Report generated by K3s Production Cluster Health Reporter*  
*Generated at: $TIMESTAMP*
