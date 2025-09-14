#!/bin/bash
set -euo pipefail

# K3s Production Cluster - VM Readiness Check
# Waits for VMs to be ready with proper readiness gates

echo "⏳ Waiting for VMs to be ready..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
MAX_RETRIES=${MAX_RETRIES:-30}
RETRY_INTERVAL=${RETRY_INTERVAL:-10}
SSH_TIMEOUT=${SSH_TIMEOUT:-300}

# Function to check cloud-init status
check_cloud_init_status() {
    local host=$1
    local max_attempts=${2:-30}
    
    echo "🔍 Checking cloud-init status on $host..."
    
    for i in $(seq 1 "$max_attempts"); do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$host" "cloud-init status --wait" 2>/dev/null; then
            echo -e "${GREEN}✅ Cloud-init completed on $host${NC}"
            return 0
        else
            echo "⏳ Cloud-init not ready on $host (attempt $i/$max_attempts)"
            sleep "$RETRY_INTERVAL"
        fi
    done
    
    echo -e "${RED}❌ Cloud-init failed to complete on $host after $max_attempts attempts${NC}"
    return 1
}

# Function to check SSH connectivity
check_ssh_connectivity() {
    local host=$1
    local max_attempts=${2:-30}
    
    echo "🔍 Checking SSH connectivity to $host..."
    
    for i in $(seq 1 "$max_attempts"); do
        if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@"$host" "echo 'SSH test successful'" 2>/dev/null; then
            echo -e "${GREEN}✅ SSH connectivity established to $host${NC}"
            return 0
        else
            echo "⏳ SSH not ready on $host (attempt $i/$max_attempts)"
            sleep "$RETRY_INTERVAL"
        fi
    done
    
    echo -e "${RED}❌ SSH connectivity failed to $host after $max_attempts attempts${NC}"
    return 1
}

# Function to check VM group readiness
check_vm_group() {
    local group_name=$1
    local hosts=("${@:2}")
    local failures=0
    
    echo "🔍 Checking $group_name group readiness..."
    
    for host in "${hosts[@]}"; do
        if [[ -n "$host" ]]; then
            # Check cloud-init status
            if ! check_cloud_init_status "$host"; then
                ((failures++))
                continue
            fi
            
            # Check SSH connectivity
            if ! check_ssh_connectivity "$host"; then
                ((failures++))
                continue
            fi
            
            echo -e "${GREEN}✅ $host is ready${NC}"
        fi
    done
    
    if [[ $failures -eq 0 ]]; then
        echo -e "${GREEN}✅ All $group_name VMs are ready${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  $failures $group_name VMs are not ready${NC}"
        return 1
    fi
}

# Function to wait for K3s API
wait_for_k3s_api() {
    local master_ip=$1
    local max_attempts=${2:-30}
    
    echo "🔍 Waiting for K3s API on $master_ip..."
    
    for i in $(seq 1 "$max_attempts"); do
        if curl -k -s https://"$master_ip":6443/healthz >/dev/null 2>&1; then
            echo -e "${GREEN}✅ K3s API is ready on $master_ip${NC}"
            return 0
        else
            echo "⏳ K3s API not ready on $master_ip (attempt $i/$max_attempts)"
            sleep "$RETRY_INTERVAL"
        fi
    done
    
    echo -e "${RED}❌ K3s API failed to start on $master_ip after $max_attempts attempts${NC}"
    return 1
}

# Main logic
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <group_name> <host1> [host2] [host3] ..."
    echo "       $0 --k3s-api <master_ip>"
    exit 1
fi

# Handle K3s API check
if [[ "$1" == "--k3s-api" ]]; then
    if [[ -z "${2:-}" ]]; then
        echo "❌ Master IP required for K3s API check"
        exit 1
    fi
    wait_for_k3s_api "$2"
    exit $?
fi

# Check VM group
GROUP_NAME="$1"
shift
HOSTS=("$@")

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "❌ No hosts provided for $GROUP_NAME group"
    exit 1
fi

check_vm_group "$GROUP_NAME" "${HOSTS[@]}"
