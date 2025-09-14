#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Known Hosts Setup
# Manages SSH known_hosts for cluster access

echo "🔐 Setting up SSH known_hosts for K3s cluster..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to add host to known_hosts
add_host_to_known_hosts() {
    local host=$1
    local port=${2:-22}
    
    echo "🔍 Adding $host:$port to known_hosts..."
    
    # Remove existing entry if any
    ssh-keygen -R "$host" -p "$port" 2>/dev/null || true
    
    # Add new entry
    if ssh-keyscan -p "$port" -H "$host" >> ~/.ssh/known_hosts 2>/dev/null; then
        echo -e "${GREEN}✅ Added $host:$port to known_hosts${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Could not add $host:$port to known_hosts (host may not be ready)${NC}"
        return 1
    fi
}

# Function to add multiple hosts
add_hosts_to_known_hosts() {
    local hosts=("$@")
    local success_count=0
    local total_count=${#hosts[@]}
    
    echo "🔍 Adding $total_count hosts to known_hosts..."
    
    for host in "${hosts[@]}"; do
        if add_host_to_known_hosts "$host"; then
            ((success_count++))
        fi
    done
    
    echo "📊 Added $success_count/$total_count hosts to known_hosts"
    
    if [[ $success_count -eq 0 ]]; then
        echo -e "${RED}❌ No hosts could be added to known_hosts${NC}"
        return 1
    elif [[ $success_count -lt $total_count ]]; then
        echo -e "${YELLOW}⚠️  Some hosts could not be added to known_hosts${NC}"
        return 0
    else
        echo -e "${GREEN}✅ All hosts added to known_hosts${NC}"
        return 0
    fi
}

# Function to disable host key checking temporarily
disable_host_key_checking() {
    echo "⚠️  Temporarily disabling host key checking..."
    echo "StrictHostKeyChecking=no" >> ~/.ssh/config
    echo "UserKnownHostsFile=/dev/null" >> ~/.ssh/config
    echo -e "${YELLOW}⚠️  Host key checking disabled (less secure)${NC}"
}

# Function to restore host key checking
restore_host_key_checking() {
    echo "🔒 Restoring host key checking..."
    # Remove the temporary config
    sed -i '/StrictHostKeyChecking=no/d' ~/.ssh/config 2>/dev/null || true
    sed -i '/UserKnownHostsFile=\/dev\/null/d' ~/.ssh/config 2>/dev/null || true
    echo -e "${GREEN}✅ Host key checking restored${NC}"
}

# Main logic
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <host1> [host2] [host3] ..."
    echo "       $0 --disable (disable host key checking)"
    echo "       $0 --restore (restore host key checking)"
    exit 1
fi

# Handle special commands
if [[ "$1" == "--disable" ]]; then
    disable_host_key_checking
    exit 0
elif [[ "$1" == "--restore" ]]; then
    restore_host_key_checking
    exit 0
fi

# Ensure known_hosts file exists
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts

# Add all provided hosts
add_hosts_to_known_hosts "$@"
