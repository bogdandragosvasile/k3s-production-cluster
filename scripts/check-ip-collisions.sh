#!/bin/bash
set -euo pipefail

# K3s Production Cluster - IP Collision Check
# Checks for IP address collisions before deployment

echo "🔍 Checking for IP address collisions..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default network configuration
NETWORK_CIDR="${NETWORK_CIDR:-192.168.122.0/24}"
MASTER_IP_OFFSET="${MASTER_IP_OFFSET:-11}"
WORKER_IP_OFFSET="${WORKER_IP_OFFSET:-21}"
STORAGE_IP_OFFSET="${STORAGE_IP_OFFSET:-31}"
LB_IP_OFFSET="${LB_IP_OFFSET:-41}"
GPU_IP_OFFSET="${GPU_IP_OFFSET:-51}"

# Node counts
MASTER_COUNT="${MASTER_COUNT:-3}"
WORKER_COUNT="${WORKER_COUNT:-3}"
STORAGE_COUNT="${STORAGE_COUNT:-2}"
LB_COUNT="${LB_COUNT:-1}"
GPU_COUNT="${GPU_COUNT:-0}"

# Function to check if IP is in use
check_ip_in_use() {
    local ip=$1
    local hostname=$2
    
    echo "🔍 Checking IP $ip for $hostname..."
    
    # Check if IP is pingable
    if ping -c 1 -W 1 "$ip" >/dev/null 2>&1; then
        echo -e "${RED}❌ IP $ip is in use (pingable)${NC}"
        return 1
    fi
    
    # Check if IP is in ARP table
    if arp -n "$ip" 2>/dev/null | grep -q "$ip"; then
        echo -e "${YELLOW}⚠️  IP $ip found in ARP table${NC}"
        return 1
    fi
    
    # Check if IP is in libvirt network
    if virsh net-dhcp-leases default 2>/dev/null | grep -q "$ip"; then
        echo -e "${YELLOW}⚠️  IP $ip found in libvirt DHCP leases${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ IP $ip is available${NC}"
    return 0
}

# Function to check IP range
check_ip_range() {
    local start_ip=$1
    local count=$2
    local node_type=$3
    local failures=0
    
    echo "🔍 Checking $node_type IP range: $start_ip - $((start_ip + count - 1))"
    
    for i in $(seq 0 $((count - 1))); do
        local ip=$((start_ip + i))
        local hostname="k3s-production-${node_type}-$((i + 1))"
        
        if ! check_ip_in_use "$ip" "$hostname"; then
            ((failures++))
        fi
    done
    
    return $failures
}

# Function to check network availability
check_network_availability() {
    echo "🔍 Checking network availability..."
    
    # Check if default network exists
    if ! virsh net-list --all | grep -q "default.*active"; then
        echo -e "${RED}❌ Default libvirt network is not active${NC}"
        return 1
    fi
    
    # Check if network is reachable
    local gateway_ip
    gateway_ip=$(ip route | grep "192.168.122" | head -1 | awk '{print $1}' | cut -d'/' -f1 | sed 's/0$/1/')
    
    if [[ -n "$gateway_ip" ]]; then
        if ping -c 1 -W 1 "$gateway_ip" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Network gateway $gateway_ip is reachable${NC}"
        else
            echo -e "${YELLOW}⚠️  Network gateway $gateway_ip is not reachable${NC}"
        fi
    fi
    
    return 0
}

# Main logic
echo "📋 IP Collision Check Configuration:"
echo "  Network CIDR: $NETWORK_CIDR"
echo "  Master nodes: $MASTER_COUNT (offset: $MASTER_IP_OFFSET)"
echo "  Worker nodes: $WORKER_COUNT (offset: $WORKER_IP_OFFSET)"
echo "  Storage nodes: $STORAGE_COUNT (offset: $STORAGE_IP_OFFSET)"
echo "  Load balancer nodes: $LB_COUNT (offset: $LB_IP_OFFSET)"
echo "  GPU nodes: $GPU_COUNT (offset: $GPU_IP_OFFSET)"
echo ""

# Check network availability
if ! check_network_availability; then
    echo -e "${RED}❌ Network availability check failed${NC}"
    exit 1
fi

# Check IP collisions
TOTAL_FAILURES=0

# Check master IPs
if ! check_ip_range "$MASTER_IP_OFFSET" "$MASTER_COUNT" "master"; then
    ((TOTAL_FAILURES++))
fi

# Check worker IPs
if ! check_ip_range "$WORKER_IP_OFFSET" "$WORKER_COUNT" "worker"; then
    ((TOTAL_FAILURES++))
fi

# Check storage IPs
if ! check_ip_range "$STORAGE_IP_OFFSET" "$STORAGE_COUNT" "storage"; then
    ((TOTAL_FAILURES++))
fi

# Check load balancer IPs
if ! check_ip_range "$LB_IP_OFFSET" "$LB_COUNT" "lb"; then
    ((TOTAL_FAILURES++))
fi

# Check GPU IPs (if any)
if [[ "$GPU_COUNT" -gt 0 ]]; then
    if ! check_ip_range "$GPU_IP_OFFSET" "$GPU_COUNT" "gpu"; then
        ((TOTAL_FAILURES++))
    fi
fi

echo ""
echo "📊 IP Collision Check Summary"

if [[ $TOTAL_FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✅ No IP collisions detected! Safe to deploy.${NC}"
    exit 0
else
    echo -e "${RED}❌ $TOTAL_FAILURES IP range(s) have collisions. Please resolve before deploying.${NC}"
    exit 1
fi
