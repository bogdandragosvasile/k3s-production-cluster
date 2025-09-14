#!/bin/bash
set -euo pipefail

# K3s Production Cluster - SSH Key Setup
# Manages SSH keys for cluster access

echo "🔑 Setting up SSH key for K3s cluster access..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default key path
KEY_PATH="/tmp/k3s-cluster-key"
PUBLIC_KEY_PATH="${KEY_PATH}.pub"

# Function to generate SSH key pair
generate_key_pair() {
    echo "🔧 Generating new SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_PATH" -N "" -C "k3s-cluster-$(date +%Y%m%d)"
    chmod 600 "$KEY_PATH"
    chmod 644 "$PUBLIC_KEY_PATH"
    echo -e "${GREEN}✅ SSH key pair generated at $KEY_PATH${NC}"
}

# Function to load key from environment
load_key_from_env() {
    if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
        echo "🔧 Loading SSH key from environment..."
        echo "$SSH_PRIVATE_KEY" | tr -d '\r' > "$KEY_PATH"
        chmod 600 "$KEY_PATH"
        
        # Generate public key from private key
        ssh-keygen -y -f "$KEY_PATH" > "$PUBLIC_KEY_PATH"
        chmod 644 "$PUBLIC_KEY_PATH"
        
        echo -e "${GREEN}✅ SSH key loaded from environment${NC}"
        return 0
    fi
    return 1
}

# Function to use existing key
use_existing_key() {
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        echo "🔧 Using existing SSH key from ~/.ssh/id_rsa..."
        cp "$HOME/.ssh/id_rsa" "$KEY_PATH"
        cp "$HOME/.ssh/id_rsa.pub" "$PUBLIC_KEY_PATH"
        chmod 600 "$KEY_PATH"
        chmod 644 "$PUBLIC_KEY_PATH"
        echo -e "${YELLOW}⚠️  Using existing SSH key (deprecated)${NC}"
        return 0
    fi
    return 1
}

# Main logic
if [[ -f "$KEY_PATH" ]]; then
    echo -e "${GREEN}✅ SSH key already exists at $KEY_PATH${NC}"
else
    # Try to load from environment first
    if load_key_from_env; then
        echo "Key loaded from environment"
    # Try to use existing key
    elif use_existing_key; then
        echo "Using existing key"
    # Generate new key pair
    else
        generate_key_pair
    fi
fi

# Verify key exists and is valid
if [[ -f "$KEY_PATH" && -f "$PUBLIC_KEY_PATH" ]]; then
    echo -e "${GREEN}✅ SSH key setup complete${NC}"
    echo "Private key: $KEY_PATH"
    echo "Public key: $PUBLIC_KEY_PATH"
    
    # Display public key for Terraform
    echo ""
    echo "Public key content:"
    cat "$PUBLIC_KEY_PATH"
    echo ""
    
    # Set environment variables for other scripts
    export SSH_PRIVATE_KEY_PATH="$KEY_PATH"
    export SSH_PUBLIC_KEY_PATH="$PUBLIC_KEY_PATH"
    
    # Write to GitHub environment if available
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "SSH_PRIVATE_KEY_PATH=$KEY_PATH" >> "$GITHUB_ENV"
        echo "SSH_PUBLIC_KEY_PATH=$PUBLIC_KEY_PATH" >> "$GITHUB_ENV"
    fi
    
    exit 0
else
    echo -e "${RED}❌ Failed to setup SSH key${NC}"
    exit 1
fi
