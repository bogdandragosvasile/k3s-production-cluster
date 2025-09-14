#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Known Hosts Setup
# Scans VM IPs and populates known_hosts for secure SSH connections

echo "🔐 Setting up known_hosts for K3s cluster VMs..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KNOWN_HOSTS_FILE="${SSH_KNOWN_HOSTS_FILE:-/tmp/k3s-ssh-$$/known_hosts}"
SSH_PORT="${SSH_PORT:-22}"
TIMEOUT="${SSH_TIMEOUT:-10}"
MAX_RETRIES="${SSH_MAX_RETRIES:-3}"

# Function to create known_hosts file
create_known_hosts_file() {
    echo -e "${BLUE}📁 Creating known_hosts file: $KNOWN_HOSTS_FILE${NC}"
    mkdir -p "$(dirname "$KNOWN_HOSTS_FILE")"
    touch "$KNOWN_HOSTS_FILE"
    chmod 600 "$KNOWN_HOSTS_FILE"
}

# Function to scan single host
scan_host() {
    local host=$1
    local port=$2
    local retry=0
    
    echo -e "${BLUE}🔍 Scanning host: $host:$port${NC}"
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        if timeout "$TIMEOUT" ssh-keyscan -p "$port" -H "$host" >> "$KNOWN_HOSTS_FILE" 2>/dev/null; then
            echo -e "${GREEN}✅ Added $host:$port to known_hosts${NC}"
            return 0
        else
            ((retry++))
            echo -e "${YELLOW}⚠️  Attempt $retry/$MAX_RETRIES failed for $host:$port${NC}"
            if [[ $retry -lt $MAX_RETRIES ]]; then
                sleep 2
            fi
        fi
    done
    
    echo -e "${RED}❌ Failed to scan $host:$port after $MAX_RETRIES attempts${NC}"
    return 1
}

# Function to scan multiple hosts
scan_hosts() {
    local hosts=("$@")
    local success_count=0
    local total_count=${#hosts[@]}
    
    echo -e "${BLUE}🔍 Scanning $total_count hosts...${NC}"
    
    for host in "${hosts[@]}"; do
        if scan_host "$host" "$SSH_PORT"; then
            ((success_count++))
        fi
    done
    
    echo -e "${BLUE}📊 Scan results: $success_count/$total_count hosts successful${NC}"
    return $((total_count - success_count))
}

# Function to display known_hosts information
display_known_hosts_info() {
    echo -e "${BLUE}📊 Known Hosts Information:${NC}"
    echo "Known hosts file: $KNOWN_HOSTS_FILE"
    echo "File size: $(wc -c < "$KNOWN_HOSTS_FILE") bytes"
    echo "Host count: $(wc -l < "$KNOWN_HOSTS_FILE")"
    
    if [[ -s "$KNOWN_HOSTS_FILE" ]]; then
        echo -e "${GREEN}✅ Known hosts file populated${NC}"
        echo "Sample entries:"
        head -3 "$KNOWN_HOSTS_FILE" | sed 's/^/  /'
        if [[ $(wc -l < "$KNOWN_HOSTS_FILE") -gt 3 ]]; then
            echo "  ..."
        fi
    else
        echo -e "${YELLOW}⚠️  Known hosts file is empty${NC}"
    fi
}

# Function to validate known_hosts
validate_known_hosts() {
    echo -e "${BLUE}🔍 Validating known_hosts file...${NC}"
    
    if [[ ! -f "$KNOWN_HOSTS_FILE" ]]; then
        echo -e "${RED}❌ Known hosts file not found${NC}"
        return 1
    fi
    
    if [[ ! -s "$KNOWN_HOSTS_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Known hosts file is empty${NC}"
        return 1
    fi
    
    # Check for valid host key entries
    local valid_entries
    valid_entries=$(grep -c '^[a-zA-Z0-9.-]* ssh-' "$KNOWN_HOSTS_FILE" || echo "0")
    
    if [[ $valid_entries -gt 0 ]]; then
        echo -e "${GREEN}✅ Found $valid_entries valid host key entries${NC}"
        return 0
    else
        echo -e "${RED}❌ No valid host key entries found${NC}"
        return 1
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS] <host1> [host2] [host3] ..."
    echo ""
    echo "Scan VM IPs and populate known_hosts for secure SSH connections"
    echo ""
    echo "OPTIONS:"
    echo "  -p, --port PORT        SSH port (default: 22)"
    echo "  -t, --timeout SECONDS  Timeout for each scan (default: 10)"
    echo "  -r, --retries COUNT    Max retries per host (default: 3)"
    echo "  -f, --file FILE        Known hosts file path"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  SSH_KNOWN_HOSTS_FILE   - Known hosts file path"
    echo "  SSH_PORT               - SSH port"
    echo "  SSH_TIMEOUT            - Timeout for scans"
    echo "  SSH_MAX_RETRIES        - Max retries per host"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.122.11 192.168.122.12 192.168.122.13"
    echo "  $0 --port 2222 --timeout 15 192.168.122.11"
    echo "  SSH_KNOWN_HOSTS_FILE=/tmp/known_hosts $0 192.168.122.11"
}

# Parse command line arguments
HOSTS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -r|--retries)
            MAX_RETRIES="$2"
            shift 2
            ;;
        -f|--file)
            KNOWN_HOSTS_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            HOSTS+=("$1")
            shift
            ;;
    esac
done

# Check if hosts are provided
if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo -e "${RED}❌ No hosts provided${NC}"
    show_help
    exit 1
fi

# Main execution
echo -e "${GREEN}🚀 Starting known_hosts setup...${NC}"

# Create known_hosts file
create_known_hosts_file

# Scan all provided hosts
scan_hosts "${HOSTS[@]}"
scan_result=$?

# Display information
display_known_hosts_info

# Validate known_hosts
validate_known_hosts
validation_result=$?

# Set environment variable
export SSH_KNOWN_HOSTS_FILE="$KNOWN_HOSTS_FILE"
if [[ -n "${GITHUB_ENV:-}" ]]; then
    echo "SSH_KNOWN_HOSTS_FILE=$KNOWN_HOSTS_FILE" >> "$GITHUB_ENV"
fi

if [[ $scan_result -eq 0 && $validation_result -eq 0 ]]; then
    echo -e "${GREEN}✅ Known hosts setup complete${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Known hosts setup completed with warnings${NC}"
    exit 1
fi
