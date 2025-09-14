#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Kubeconfig Sanitizer
# Sanitizes kubeconfig files by redacting secrets and sensitive information

echo "🔒 Sanitizing kubeconfig for safe artifact upload..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INPUT_KUBECONFIG=${1:-./kubeconfig}
OUTPUT_KUBECONFIG=${2:-./kubeconfig-sanitized}
BACKUP_SUFFIX=".backup"

# Function to log with timestamp
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Function to check if input file exists
check_input_file() {
    if [[ ! -f "$INPUT_KUBECONFIG" ]]; then
        log "ERROR" "Input kubeconfig not found: $INPUT_KUBECONFIG"
        exit 1
    fi
    
    log "INFO" "Input kubeconfig found: $INPUT_KUBECONFIG"
}

# Function to create backup
create_backup() {
    local backup_file="${INPUT_KUBECONFIG}${BACKUP_SUFFIX}"
    
    log "INFO" "Creating backup: $backup_file"
    cp "$INPUT_KUBECONFIG" "$backup_file"
    log "SUCCESS" "Backup created: $backup_file"
}

# Function to sanitize kubeconfig
sanitize_kubeconfig() {
    log "INFO" "Sanitizing kubeconfig..."
    
    # Create sanitized version
    cp "$INPUT_KUBECONFIG" "$OUTPUT_KUBECONFIG"
    
    # Replace server IP with placeholder
    sed -i 's/server: https:\/\/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+:6443/server: https:\/\/<MASTER_IP>:6443/g' "$OUTPUT_KUBECONFIG"
    
    # Replace any remaining IP addresses with placeholders
    sed -i 's/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/<IP_ADDRESS>/g' "$OUTPUT_KUBECONFIG"
    
    # Replace certificate data with placeholders
    sed -i 's/certificate-authority-data: [A-Za-z0-9+/=]\+/certificate-authority-data: <REDACTED>/g' "$OUTPUT_KUBECONFIG"
    sed -i 's/client-certificate-data: [A-Za-z0-9+/=]\+/client-certificate-data: <REDACTED>/g' "$OUTPUT_KUBECONFIG"
    sed -i 's/client-key-data: [A-Za-z0-9+/=]\+/client-key-data: <REDACTED>/g' "$OUTPUT_KUBECONFIG"
    
    # Replace any remaining base64 data with placeholders
    sed -i 's/[A-Za-z0-9+/=]\{20,\}/<REDACTED>/g' "$OUTPUT_KUBECONFIG"
    
    # Add warning header
    cat > "${OUTPUT_KUBECONFIG}.tmp" << EOF
# WARNING: This kubeconfig has been sanitized for security
# Original sensitive data has been replaced with placeholders
# To use this kubeconfig, replace placeholders with actual values:
# - <MASTER_IP> with the actual master node IP address
# - <REDACTED> with the actual certificate/key data
# - <IP_ADDRESS> with actual IP addresses
#
# Generated: $(date)
# Original file: $INPUT_KUBECONFIG
#

