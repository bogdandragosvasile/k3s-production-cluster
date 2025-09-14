#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Ephemeral SSH Key Management
# Loads SSH_PRIVATE_KEY from secrets into ephemeral files and starts SSH agent

echo "🔑 Setting up ephemeral SSH key management..."

# Colors for output
GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SSH_DIR="/tmp/k3s-ssh-$$"
SSH_PRIVATE_KEY_FILE="$SSH_DIR/id_rsa"
SSH_PUBLIC_KEY_FILE="$SSH_DIR/id_rsa.pub"
SSH_KNOWN_HOSTS_FILE="$SSH_DIR/known_hosts"
SSH_SOCKET="$SSH_DIR/ssh-agent.sock"

# Function to create ephemeral SSH directory
create_ssh_directory() {
    echo -e "${BLUE}📁 Creating ephemeral SSH directory: $SSH_DIR${NC}"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
}

# Function to load SSH key from secrets
load_ssh_key() {
    echo -e "${BLUE}🔐 Loading SSH key from secrets...${NC}"
    
    if [[ -z "${SSH_PRIVATE_KEY:-}" ]]; then
        echo -e "${RED}❌ SSH_PRIVATE_KEY secret not found${NC}"
        echo "Please set the SSH_PRIVATE_KEY repository secret or environment variable"
        exit 1
    fi
    
    # Write private key to ephemeral file
    echo "$SSH_PRIVATE_KEY" | tr -d '\r' > "$SSH_PRIVATE_KEY_FILE"
    chmod 600 "$SSH_PRIVATE_KEY_FILE"
    
    # Generate public key from private key
    ssh-keygen -y -f "$SSH_PRIVATE_KEY_FILE" > "$SSH_PUBLIC_KEY_FILE"
    chmod 644 "$SSH_PUBLIC_KEY_FILE"
    
    echo -e "${GREEN}✅ SSH key loaded from secrets${NC}"
}

# Function to start SSH agent
start_ssh_agent() {
    echo -e "${BLUE}🚀 Starting SSH agent...${NC}"
    
    # Start SSH agent with custom socket
    eval "$(ssh-agent -a "$SSH_SOCKET")"
    
    # Add private key to agent
    ssh-add "$SSH_PRIVATE_KEY_FILE"
    
    # Verify key is loaded
    local key_fingerprint
    key_fingerprint=$(ssh-add -l | grep -o 'SHA256:[A-Za-z0-9+/=]*' | head -1)
    
    if [[ -n "$key_fingerprint" ]]; then
        echo -e "${GREEN}✅ SSH agent started with key fingerprint: $key_fingerprint${NC}"
    else
        echo -e "${RED}❌ Failed to load key into SSH agent${NC}"
        exit 1
    fi
}

# Function to display key information (without private material)
display_key_info() {
    echo -e "${BLUE}📊 SSH Key Information:${NC}"
    echo "Private key file: $SSH_PRIVATE_KEY_FILE"
    echo "Public key file: $SSH_PUBLIC_KEY_FILE"
    echo "Known hosts file: $SSH_KNOWN_HOSTS_FILE"
    echo "SSH agent socket: $SSH_SOCKET"
    
    # Display public key fingerprint
    local pub_fingerprint
    pub_fingerprint=$(ssh-keygen -lf "$SSH_PUBLIC_KEY_FILE" | awk '{print $2}')
    echo "Public key fingerprint: $pub_fingerprint"
    
    # Display key type and size
    local key_type key_size
    key_type=$(ssh-keygen -lf "$SSH_PUBLIC_KEY_FILE" | awk '{print $1}')
    key_size=$(ssh-keygen -lf "$SSH_PUBLIC_KEY_FILE" | awk '{print $1}' | cut -d: -f2)
    echo "Key type: $key_type"
    echo "Key size: $key_size bits"
    
    # Display first few characters of public key (safe to show)
    echo "Public key (first 50 chars): $(head -c 50 "$SSH_PUBLIC_KEY_FILE")..."
}

# Function to set environment variables
set_environment() {
    echo -e "${BLUE}🔧 Setting environment variables...${NC}"
    
    # Export SSH agent socket
    export SSH_AUTH_SOCK="$SSH_SOCKET"
    export SSH_AGENT_PID="$SSH_AGENT_PID"
    
    # Export file paths
    export SSH_PRIVATE_KEY_FILE="$SSH_PRIVATE_KEY_FILE"
    export SSH_PUBLIC_KEY_FILE="$SSH_PUBLIC_KEY_FILE"
    export SSH_KNOWN_HOSTS_FILE="$SSH_KNOWN_HOSTS_FILE"
    
    # Write to GitHub environment if available
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        { echo "SSH_AUTH_SOCK=$SSH_SOCKET"; echo "SSH_AGENT_PID=$SSH_AGENT_PID"; echo "SSH_PRIVATE_KEY_FILE=$SSH_PRIVATE_KEY_FILE"; echo "SSH_PUBLIC_KEY_FILE=$SSH_PUBLIC_KEY_FILE"; echo "SSH_KNOWN_HOSTS_FILE=$SSH_KNOWN_HOSTS_FILE"; } >> "$GITHUB_ENV"
    fi
    
    echo -e "${GREEN}✅ Environment variables set${NC}"
}

# Function to create SSH config
create_ssh_config() {
    echo -e "${BLUE}⚙️  Creating SSH config...${NC}"
    
    cat > "$SSH_DIR/config" << CONFIG_EOF
# K3s Production Cluster SSH Configuration
# Generated at $(date)

Host *
    IdentityFile $SSH_PRIVATE_KEY_FILE
    UserKnownHostsFile $SSH_KNOWN_HOSTS_FILE
    StrictHostKeyChecking yes
    IdentitiesOnly yes
    LogLevel ERROR
CONFIG_EOF
    
    chmod 600 "$SSH_DIR/config"
    export SSH_CONFIG="$SSH_DIR/config"
    
    if [[ -n "${GITHUB_ENV:-}" ]]; then
        echo "SSH_CONFIG=$SSH_DIR/config" >> "$GITHUB_ENV"
    fi
    
    echo -e "${GREEN}✅ SSH config created${NC}"
}

# Function to cleanup on exit
cleanup() {
    echo -e "${BLUE}🧹 Cleaning up ephemeral SSH files...${NC}"
    if [[ -n "${SSH_AGENT_PID:-}" ]]; then
        ssh-agent -k 2>/dev/null || true
    fi
    rm -rf "$SSH_DIR" 2>/dev/null || true
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
echo -e "${GREEN}🚀 Starting ephemeral SSH setup...${NC}"

# Create SSH directory
create_ssh_directory

# Load SSH key from secrets
load_ssh_key

# Start SSH agent
start_ssh_agent

# Create SSH config
create_ssh_config

# Set environment variables
set_environment

# Display key information
display_key_info

echo -e "${GREEN}✅ Ephemeral SSH setup complete${NC}"
echo -e "${BLUE}💡 SSH agent is running and ready for use${NC}"
