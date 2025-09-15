#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Preflight Checks
# Validates runner environment and required tools

echo "🔍 Running preflight checks for K3s Production Cluster deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command exists
check_command() {
    local cmd=$1
    local name=$2
    local version_flag=${3:---version}
    
    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$($cmd "$version_flag" 2>&1 | head -1)
        echo -e "${GREEN}✅ $name: $version${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: Not found${NC}"
        return 1
    fi
}

# Function to check sudo access
check_sudo_access() {
    local cmd=$1
    local name=$2
    
    if sudo -n "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $name: Sudo access available${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: No sudo access${NC}"
        return 1
    fi
}

# Track failures
FAILURES=0

echo ""
echo "📋 Checking required tools..."

# Check basic tools
check_command "virsh" "libvirt CLI" || ((FAILURES++))
check_command "qemu-system-x86_64" "QEMU KVM" || ((FAILURES++))
check_command "terraform" "Terraform" || ((FAILURES++))
check_command "ansible" "Ansible" || ((FAILURES++))
check_command "kubectl" "kubectl" || ((FAILURES++))

echo ""
echo "🔐 Checking permissions..."

# Check sudo access for libvirt
# Check virsh commands directly (user should be in libvirt group)
if virsh version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ virsh version: Working${NC}"
else
    echo -e "${RED}❌ virsh version: Failed - check libvirt group membership${NC}"
    ((FAILURES++))
fi

if virsh list >/dev/null 2>&1; then
    echo -e "${GREEN}✅ virsh list: Working${NC}"
else
    echo -e "${RED}❌ virsh list: Failed - check libvirt group membership${NC}"
    ((FAILURES++))
fi

# Check if user is in libvirt group
if groups | grep -q libvirt; then
    echo -e "${GREEN}✅ libvirt group membership: User in libvirt group${NC}"
else
    echo -e "${YELLOW}⚠️  libvirt group membership: User not in libvirt group (may need sudo)${NC}"
fi

echo ""
echo "🌐 Checking libvirt environment..."

# Check libvirt daemon
if systemctl is-active --quiet libvirtd; then
    echo -e "${GREEN}✅ libvirtd service: Running${NC}"
else
    echo -e "${RED}❌ libvirtd service: Not running${NC}"
    ((FAILURES++))
fi

# Check default pool
if virsh pool-list --all | grep -q "default.*active"; then
    echo -e "${GREEN}✅ libvirt default pool: Available${NC}"
else
    echo -e "${RED}❌ libvirt default pool: Not available${NC}"
    ((FAILURES++))
fi

# Check default network
if virsh net-list --all | grep -q "default.*active"; then
    echo -e "${GREEN}✅ libvirt default network: Available${NC}"
else
    echo -e "${RED}❌ libvirt default network: Not available${NC}"
    ((FAILURES++))
fi

echo ""
echo "📁 Checking workspace..."

# Check if we're in a git repository
if [[ -d ".git" ]]; then
    echo -e "${GREEN}✅ Git repository: Detected${NC}"
else
    echo -e "${RED}❌ Git repository: Not detected${NC}"
    ((FAILURES++))
fi

# Check required directories
for dir in "terraform" "ansible" "scripts"; do
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✅ Directory $dir: Exists${NC}"
    else
        echo -e "${RED}❌ Directory $dir: Missing${NC}"
        ((FAILURES++))
    fi
done

echo ""
echo "🔑 Checking SSH configuration..."

# Check SSH agent
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    echo -e "${GREEN}✅ SSH agent: Running${NC}"
else
    echo -e "${YELLOW}⚠️  SSH agent: Not running (will use provided key)${NC}"
fi

# Check if we have a private key (either from SSH agent or file)
if [[ -n "${SSH_PRIVATE_KEY:-}" ]]; then
    echo -e "${GREEN}✅ SSH private key: Available from environment${NC}"
elif [[ -f "$HOME/.ssh/id_rsa" ]]; then
    echo -e "${YELLOW}⚠️  SSH private key: Using ~/.ssh/id_rsa (deprecated)${NC}"
else
    echo -e "${RED}❌ SSH private key: Not found${NC}"
    ((FAILURES++))
fi

echo ""
echo "🌍 Checking system resources..."

# Check available memory (need at least 8GB for 3 masters + 3 workers)
TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
if [[ $TOTAL_MEM -ge 8192 ]]; then
    echo -e "${GREEN}✅ System memory: ${TOTAL_MEM}MB (sufficient)${NC}"
else
    echo -e "${YELLOW}⚠️  System memory: ${TOTAL_MEM}MB (may be insufficient for full cluster)${NC}"
fi

# Check available disk space (need at least 20GB)
AVAILABLE_DISK=$(df / | awk 'NR==2{print $4}')
if [[ $AVAILABLE_DISK -ge 20971520 ]]; then  # 20GB in KB
    echo -e "${GREEN}✅ Disk space: $((AVAILABLE_DISK / 1024 / 1024))GB available (sufficient)${NC}"
else
    echo -e "${YELLOW}⚠️  Disk space: $((AVAILABLE_DISK / 1024 / 1024))GB available (may be insufficient)${NC}"
fi

echo ""
echo "📊 Preflight Summary"

if [[ $FAILURES -eq 0 ]]; then
    echo -e "${GREEN}✅ All preflight checks passed! Ready to deploy.${NC}"
    exit 0
else
    echo -e "${RED}❌ $FAILURES preflight check(s) failed. Please fix the issues above before deploying.${NC}"
    exit 1
fi
