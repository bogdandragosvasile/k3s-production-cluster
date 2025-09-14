#!/bin/bash
set -euo pipefail

# K3s Production Cluster - Cloud-Init Readiness Gate
# Waits for cloud-init completion on VMs with exponential backoff and structured logging

echo "☁️  Cloud-Init Readiness Gate - Starting VM readiness checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_ATTEMPTS=${MAX_ATTEMPTS:-30}
BASE_DELAY=${BASE_DELAY:-5}
MAX_DELAY=${MAX_DELAY:-60}
TIMEOUT=${TIMEOUT:-600}  # 10 minutes total timeout
LOG_FILE=${LOG_FILE:-/tmp/cloud-init-readiness.log}

# Initialize log file
echo "=== Cloud-Init Readiness Gate - $(date) ===" > "$LOG_FILE"

# Function to log with timestamp
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp; timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Function to calculate exponential backoff delay
calculate_delay() {
    local attempt=$1
    local delay=$((BASE_DELAY * (2 ** (attempt - 1))))
    if [[ $delay -gt $MAX_DELAY ]]; then
        delay=$MAX_DELAY
    fi
    echo "$delay"
}

# Function to check cloud-init status on a single VM
check_cloud_init_status() {
    local vm_ip=$1
    local vm_name=$2
    local attempt=$3
    
    log "INFO" "Checking cloud-init status on $vm_name ($vm_ip) - attempt $attempt"
    
    # Check if VM is reachable first
    if ! ping -c 1 -W 5 "$vm_ip" >/dev/null 2>&1; then
        log "WARN" "VM $vm_name ($vm_ip) not reachable via ping"
        return 1
    fi
    
    # Check cloud-init status via SSH
    local ssh_cmd="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@$vm_ip"
    
    if timeout 30 "$ssh_cmd" "cloud-init status --wait" >/dev/null 2>&1; then
        log "SUCCESS" "Cloud-init completed on $vm_name ($vm_ip)"
        return 0
    else
        log "WARN" "Cloud-init not ready on $vm_name ($vm_ip) - attempt $attempt"
        return 1
    fi
}

# Function to check all VMs in parallel
check_all_vms() {
    local vms=("$@")
    local failed_vms=()
    local success_count=0
    
    log "INFO" "Checking cloud-init status on ${#vms[@]} VMs in parallel"
    
    for vm_info in "${vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        
        if check_cloud_init_status "$vm_ip" "$vm_name" "parallel"; then
            ((success_count++))
            echo -e "${GREEN}✅ $vm_name ($vm_ip) - Cloud-init ready${NC}"
        else
            failed_vms+=("$vm_info")
            echo -e "${YELLOW}⏳ $vm_name ($vm_ip) - Cloud-init not ready${NC}"
        fi
    done
    
    log "INFO" "Parallel check complete: $success_count/${#vms[@]} VMs ready"
    
    if [[ ${#failed_vms[@]} -eq 0 ]]; then
        return 0
    else
        printf '%s\n' "${failed_vms[@]}"
        return 1
    fi
}

# Function to wait for specific VMs with retries
wait_for_vms() {
    local vms=("$@")
    local remaining_vms=("${vms[@]}")
    local start_time; start_time=$(date +%s)
    
    log "INFO" "Starting cloud-init readiness wait for ${#vms[@]} VMs"
    
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        local current_time; current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $TIMEOUT ]]; then
            log "ERROR" "Timeout reached after ${elapsed}s (limit: ${TIMEOUT}s)"
            break
        fi
        
        log "INFO" "Attempt $attempt/$MAX_ATTEMPTS (elapsed: ${elapsed}s)"
        
        # Check remaining VMs
        local still_failing=()
        for vm_info in "${remaining_vms[@]}"; do
            IFS='|' read -r vm_ip vm_name <<< "$vm_info"
            
            if check_cloud_init_status "$vm_ip" "$vm_name" "$attempt"; then
                echo -e "${GREEN}✅ $vm_name ($vm_ip) - Cloud-init ready${NC}"
            else
                still_failing+=("$vm_info")
                echo -e "${YELLOW}⏳ $vm_name ($vm_ip) - Cloud-init not ready${NC}"
            fi
        done
        
        # Update remaining VMs
        remaining_vms=("${still_failing[@]}")
        
        # Check if all VMs are ready
        if [[ ${#remaining_vms[@]} -eq 0 ]]; then
            local total_time=$((current_time - start_time))
            log "SUCCESS" "All VMs ready after ${total_time}s (attempt $attempt)"
            echo -e "${GREEN}🎉 All VMs have completed cloud-init!${NC}"
            return 0
        fi
        
        # Calculate delay for next attempt
        local delay; delay=$(calculate_delay "$attempt")
        log "INFO" "Waiting ${delay}s before next attempt (${#remaining_vms[@]} VMs still pending)"
        sleep "$delay"
    done
    
    # Final failure report
    log "ERROR" "Cloud-init readiness check failed after $MAX_ATTEMPTS attempts"
    echo -e "${RED}❌ Cloud-init readiness check failed for ${#remaining_vms[@]} VMs:${NC}"
    for vm_info in "${remaining_vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        echo -e "${RED}  - $vm_name ($vm_ip)${NC}"
    done
    
    return 1
}

# Function to generate readiness report
generate_readiness_report() {
    local vms=("$@")
    local report_file="/tmp/cloud-init-readiness-report.txt"
    
    echo "=== Cloud-Init Readiness Report ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "Total VMs: ${#vms[@]}" >> "$report_file"
    echo "" >> "$report_file"
    
    for vm_info in "${vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        echo "VM: $vm_name ($vm_ip)" >> "$report_file"
        
        # Check final status
        if check_cloud_init_status "$vm_ip" "$vm_name" "final" 2>/dev/null; then
            echo "  Status: READY" >> "$report_file"
        else
            echo "  Status: NOT READY" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    echo "Report saved to: $report_file"
    echo "LOG_FILE=$report_file" >> "$GITHUB_ENV"
}

# Main execution
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <vm_ip1>|<vm_name1> [<vm_ip2>|<vm_name2> ...]"
    echo "Example: $0 192.168.122.11|master-1 192.168.122.12|worker-1"
    exit 1
fi

# Parse VM arguments
vms=()
for vm_arg in "$@"; do
    if [[ "$vm_arg" == *"|"* ]]; then
        vms+=("$vm_arg")
    else
        echo -e "${RED}❌ Invalid VM format: $vm_arg (expected: ip|name)${NC}"
        exit 1
    fi
done

log "INFO" "Starting cloud-init readiness gate for ${#vms[@]} VMs"
log "INFO" "Configuration: MAX_ATTEMPTS=$MAX_ATTEMPTS, BASE_DELAY=$BASE_DELAY, MAX_DELAY=$MAX_DELAY, TIMEOUT=$TIMEOUT"

# First, do a parallel check to see current status
echo -e "${BLUE}🔍 Initial parallel check...${NC}"
if check_all_vms "${vms[@]}"; then
    echo -e "${GREEN}🎉 All VMs already ready!${NC}"
    generate_readiness_report "${vms[@]}"
    exit 0
fi

# Wait for remaining VMs
echo -e "${BLUE}⏳ Waiting for remaining VMs...${NC}"
if wait_for_vms "${vms[@]}"; then
    generate_readiness_report "${vms[@]}"
    exit 0
else
    generate_readiness_report "${vms[@]}"
    exit 1
fi
