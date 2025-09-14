#!/bin/bash
set -euo pipefail

# K3s Production Cluster - SSH Setup Demonstration
# Demonstrates end-to-end SSH key management and known_hosts setup

echo "🎯 K3s Production Cluster - SSH Setup Demonstration"
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
# RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_SSH_DIR="/tmp/k3s-ssh-demo-$$"
DEMO_KNOWN_HOSTS_FILE="$DEMO_SSH_DIR/known_hosts"
DEMO_PRIVATE_KEY_FILE="$DEMO_SSH_DIR/id_rsa"
DEMO_PUBLIC_KEY_FILE="$DEMO_SSH_DIR/id_rsa.pub"

# Function to create demo SSH key
create_demo_ssh_key() {
    echo -e "${BLUE}🔑 Creating demo SSH key pair...${NC}"
    
    # Create demo directory
    mkdir -p "$DEMO_SSH_DIR"
    chmod 700 "$DEMO_SSH_DIR"
    
    # Generate SSH key pair
    ssh-keygen -t rsa -b 4096 -f "$DEMO_PRIVATE_KEY_FILE" -N "" -C "k3s-demo-$(date +%Y%m%d)"
    chmod 600 "$DEMO_PRIVATE_KEY_FILE"
    chmod 644 "$DEMO_PUBLIC_KEY_FILE"
    
    echo -e "${GREEN}✅ Demo SSH key pair created${NC}"
}

# Function to demonstrate SSH key information
demonstrate_ssh_key_info() {
    echo -e "${BLUE}📊 SSH Key Information:${NC}"
    echo "Private key file: $DEMO_PRIVATE_KEY_FILE"
    echo "Public key file: $DEMO_PUBLIC_KEY_FILE"
    echo "Known hosts file: $DEMO_KNOWN_HOSTS_FILE"
    
    # Display file sizes
    echo "Private key size: $(wc -c < "$DEMO_PRIVATE_KEY_FILE") bytes"
    echo "Public key size: $(wc -c < "$DEMO_PUBLIC_KEY_FILE") bytes"
    
    # Display public key fingerprint
    local pub_fingerprint
    pub_fingerprint=$(ssh-keygen -lf "$DEMO_PUBLIC_KEY_FILE" | awk '{print $2}')
    echo "Public key fingerprint: $pub_fingerprint"
    
    # Display key type and size
    local key_type key_size
    key_type=$(ssh-keygen -lf "$DEMO_PUBLIC_KEY_FILE" | awk '{print $1}')
    key_size=$(ssh-keygen -lf "$DEMO_PUBLIC_KEY_FILE" | awk '{print $1}' | cut -d: -f2)
    echo "Key type: $key_type"
    echo "Key size: $key_size bits"
    
    # Display first few characters of public key (safe to show)
    echo "Public key (first 50 chars): $(head -c 50 "$DEMO_PUBLIC_KEY_FILE")..."
    
    # Display public key content (safe to show)
    echo -e "${BLUE}📄 Public Key Content:${NC}"
    cat "$DEMO_PUBLIC_KEY_FILE"
}

# Function to demonstrate known_hosts setup
demonstrate_known_hosts() {
    echo -e "${BLUE}🔐 Demonstrating known_hosts setup...${NC}"
    
    # Create known_hosts file
    touch "$DEMO_KNOWN_HOSTS_FILE"
    chmod 600 "$DEMO_KNOWN_HOSTS_FILE"
    
    # Simulate scanning some example hosts
    local example_hosts=("192.168.122.11" "192.168.122.12" "192.168.122.13")
    
    echo "Example hosts to scan: ${example_hosts[*]}"
    
    # Note: In real usage, these would be actual VM IPs
    echo -e "${YELLOW}⚠️  Note: In real usage, these would be actual VM IPs from Terraform output${NC}"
    
    # Create some example known_hosts entries
    cat > "$DEMO_KNOWN_HOSTS_FILE" << KNOWN_HOSTS_EOF
# Example known_hosts entries (simulated)
192.168.122.11 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... (example)
192.168.122.12 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... (example)
192.168.122.13 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... (example)
KNOWN_HOSTS_EOF
    
    echo -e "${GREEN}✅ Known hosts file created with example entries${NC}"
}

# Function to demonstrate known_hosts information
demonstrate_known_hosts_info() {
    echo -e "${BLUE}📊 Known Hosts Information:${NC}"
    echo "Known hosts file: $DEMO_KNOWN_HOSTS_FILE"
    echo "File size: $(wc -c < "$DEMO_KNOWN_HOSTS_FILE") bytes"
    echo "Host count: $(wc -l < "$DEMO_KNOWN_HOSTS_FILE")"
    
    if [[ -s "$DEMO_KNOWN_HOSTS_FILE" ]]; then
        echo -e "${GREEN}✅ Known hosts file populated${NC}"
        echo "Sample entries:"
        head -3 "$DEMO_KNOWN_HOSTS_FILE" | sed 's/^/  /'
        if [[ $(wc -l < "$DEMO_KNOWN_HOSTS_FILE") -gt 3 ]]; then
            echo "  ..."
        fi
    else
        echo -e "${YELLOW}⚠️  Known hosts file is empty${NC}"
    fi
}

# Function to demonstrate SSH agent
demonstrate_ssh_agent() {
    echo -e "${BLUE}🚀 Demonstrating SSH agent setup...${NC}"
    
    # Start SSH agent
    local ssh_socket="$DEMO_SSH_DIR/ssh-agent.sock"
    eval "$(ssh-agent -a "$ssh_socket")"
    
    # Add private key to agent
    ssh-add "$DEMO_PRIVATE_KEY_FILE"
    
    # Display agent information
    echo "SSH agent socket: $ssh_socket"
    echo "SSH agent PID: $SSH_AGENT_PID"
    
    # List loaded keys
    echo "Loaded keys:"
    ssh-add -l | sed 's/^/  /'
    
    # Clean up agent
    ssh-agent -k 2>/dev/null || true
}

# Function to demonstrate Terraform integration
demonstrate_terraform_integration() {
    echo -e "${BLUE}🏗️  Demonstrating Terraform integration...${NC}"
    
    # Show how public key would be passed to Terraform
    echo "Terraform variable:"
    echo "TF_VAR_ssh_public_key=\"$(cat "$DEMO_PUBLIC_KEY_FILE")\""
    
    # Show how private key path would be used in Ansible inventory
    echo "Ansible inventory SSH key path:"
    echo "ansible_ssh_private_key_file=$DEMO_PRIVATE_KEY_FILE"
    
    # Show SSH config that would be used
    echo "SSH config:"
    cat << CONFIG_EOF
Host *
    IdentityFile $DEMO_PRIVATE_KEY_FILE
    UserKnownHostsFile $DEMO_KNOWN_HOSTS_FILE
    StrictHostKeyChecking yes
    IdentitiesOnly yes
CONFIG_EOF
}

# Function to cleanup demo files
cleanup_demo() {
    echo -e "${BLUE}🧹 Cleaning up demo files...${NC}"
    rm -rf "$DEMO_SSH_DIR"
    echo -e "${GREEN}✅ Demo cleanup complete${NC}"
}

# Function to show real workflow usage
show_real_workflow() {
    echo -e "${BLUE}🔄 Real Workflow Usage:${NC}"
    echo ""
    echo "1. Repository Secret Setup:"
    echo "   - Set SSH_PRIVATE_KEY repository secret with your private key"
    echo ""
    echo "2. Workflow Execution:"
    echo "   - ./scripts/setup-ssh-ephemeral.sh loads key from secrets"
    echo "   - ./scripts/setup-known-hosts.sh scans VM IPs from Terraform"
    echo "   - Terraform uses generated public key for cloud-init"
    echo "   - Ansible uses ephemeral private key for SSH connections"
    echo ""
    echo "3. Security Features:"
    echo "   - No hardcoded paths or ~/.ssh assumptions"
    echo "   - Ephemeral files cleaned up after use"
    echo "   - SSH agent with fingerprint verification"
    echo "   - Known hosts populated from actual VM IPs"
    echo ""
    echo "4. Environment Variables:"
    echo "   - SSH_PRIVATE_KEY_FILE: Path to ephemeral private key"
    echo "   - SSH_PUBLIC_KEY_FILE: Path to ephemeral public key"
    echo "   - SSH_KNOWN_HOSTS_FILE: Path to ephemeral known_hosts"
    echo "   - SSH_AUTH_SOCK: SSH agent socket"
}

# Main execution
echo -e "${GREEN}🚀 Starting SSH setup demonstration...${NC}"

# Create demo SSH key
create_demo_ssh_key

# Demonstrate SSH key information
demonstrate_ssh_key_info

# Demonstrate known_hosts setup
demonstrate_known_hosts

# Demonstrate known_hosts information
demonstrate_known_hosts_info

# Demonstrate SSH agent
demonstrate_ssh_agent

# Demonstrate Terraform integration
demonstrate_terraform_integration

# Show real workflow usage
show_real_workflow

# Cleanup
cleanup_demo

echo -e "${GREEN}✅ SSH setup demonstration complete${NC}"
echo -e "${BLUE}💡 This demonstrates the secure, ephemeral SSH handling used in the K3s production cluster${NC}"
