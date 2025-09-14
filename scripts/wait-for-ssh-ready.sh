#!/bin/bash
set -euo pipefail

# K3s Production Cluster - SSH Readiness Gate
# Performs parallel SSH reachability probes with aggregate reporting

echo "🔐 SSH Readiness Gate - Starting parallel SSH connectivity checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_ATTEMPTS=${MAX_ATTEMPTS:-20}
BASE_DELAY=${BASE_DELAY:-3}
MAX_DELAY=${MAX_DELAY:-30}
TIMEOUT=${TIMEOUT:-300}  # 5 minutes total timeout
SSH_TIMEOUT=${SSH_TIMEOUT:-10}  # Individual SSH connection timeout
LOG_FILE=${LOG_FILE:-/tmp/ssh-readiness.log}

# Initialize log file
echo "=== SSH Readiness Gate - $(date) ===" > "$LOG_FILE"

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

# Function to test SSH connectivity to a single VM
test_ssh_connectivity() {
    local vm_ip=$1
    local vm_name=$2
    local attempt=$3
    
    log "INFO" "Testing SSH connectivity to $vm_name ($vm_ip) - attempt $attempt"
    
    # Test basic connectivity first
    if ! ping -c 1 -W 5 "$vm_ip" >/dev/null 2>&1; then
        log "WARN" "VM $vm_name ($vm_ip) not reachable via ping"
        return 1
    fi
    
    # Test SSH connectivity
    local ssh_cmd="ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes ubuntu@$vm_ip"
    
    if timeout $((SSH_TIMEOUT + 5)) "$ssh_cmd" "echo 'SSH test successful'" >/dev/null 2>&1; then
        log "SUCCESS" "SSH connectivity confirmed to $vm_name ($vm_ip)"
        return 0
    else
        log "WARN" "SSH connectivity failed to $vm_name ($vm_ip) - attempt $attempt"
        return 1
    fi
}

# Function to test SSH connectivity in parallel
test_ssh_parallel() {
    local vms=("$@")
    local results=()
    local success_count=0
    local failed_count=0
    
    log "INFO" "Testing SSH connectivity to ${#vms[@]} VMs in parallel"
    
    # Create temporary files for parallel execution
    local temp_dir; temp_dir=$(mktemp -d)
    local pids=()
    local vm_index=0
    
    for vm_info in "${vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        local result_file="$temp_dir/result_$vm_index"
        local vm_file="$temp_dir/vm_$vm_index"
        echo "$vm_info" > "$vm_file"
        
        # Start background process for this VM
        (
            if test_ssh_connectivity "$vm_ip" "$vm_name" "parallel"; then
                echo "SUCCESS" > "$result_file"
            else
                echo "FAILED" > "$result_file"
            fi
        ) &
        
        pids+=($!)
        ((vm_index++))
    done
    
    # Wait for all background processes to complete
    local timeout_duration=$((SSH_TIMEOUT + 10))
    
    for pid in "${pids[@]}"; do
        local wait_start; wait_start=$(date +%s)
        while kill -0 "$pid" 2>/dev/null; do
            local current_time; current_time=$(date +%s)
            local elapsed=$((current_time - wait_start))
            
            if [[ $elapsed -gt $timeout_duration ]]; then
                log "WARN" "SSH test process $pid timed out after ${elapsed}s"
                kill -9 "$pid" 2>/dev/null || true
                break
            fi
            sleep 1
        done
        wait "$pid" 2>/dev/null || true
    done
    
    # Collect results
    vm_index=0
    for vm_info in "${vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        local result_file="$temp_dir/result_$vm_index"
        
        if [[ -f "$result_file" ]]; then
            local result; result=$(cat "$result_file")
            if [[ "$result" == "SUCCESS" ]]; then
                echo -e "${GREEN}✅ $vm_name ($vm_ip) - SSH ready${NC}"
                ((success_count++))
                results+=("SUCCESS|$vm_info")
            else
                echo -e "${YELLOW}⏳ $vm_name ($vm_ip) - SSH not ready${NC}"
                ((failed_count++))
                results+=("FAILED|$vm_info")
            fi
        else
            echo -e "${RED}❌ $vm_name ($vm_ip) - SSH test failed${NC}"
            ((failed_count++))
            results+=("FAILED|$vm_info")
        fi
        
        ((vm_index++))
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log "INFO" "Parallel SSH test complete: $success_count/${#vms[@]} VMs ready"
    
    # Return results
    printf '%s\n' "${results[@]}"
    
    if [[ $failed_count -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for SSH connectivity with retries
wait_for_ssh() {
    local vms=("$@")
    local remaining_vms=("${vms[@]}")
    local start_time; start_time=$(date +%s)
    
    log "INFO" "Starting SSH readiness wait for ${#vms[@]} VMs"
    
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        local current_time; current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $TIMEOUT ]]; then
            log "ERROR" "Timeout reached after ${elapsed}s (limit: ${TIMEOUT}s)"
            break
        fi
        
        log "INFO" "Attempt $attempt/$MAX_ATTEMPTS (elapsed: ${elapsed}s)"
        
        # Test remaining VMs in parallel
        local results=()
        while IFS= read -r result_line; do
            results+=("$result_line")
        done < <(test_ssh_parallel "${remaining_vms[@]}")
        
        # Process results
        local still_failing=()
        for result_line in "${results[@]}"; do
            IFS='|' read -r status vm_info <<< "$result_line"
            
            if [[ "$status" == "SUCCESS" ]]; then
                IFS='|' read -r vm_ip vm_name <<< "$vm_info"
                echo -e "${GREEN}✅ $vm_name ($vm_ip) - SSH ready${NC}"
            else
                still_failing+=("$vm_info")
                IFS='|' read -r vm_ip vm_name <<< "$vm_info"
                echo -e "${YELLOW}⏳ $vm_name ($vm_ip) - SSH not ready${NC}"
            fi
        done
        
        # Update remaining VMs
        remaining_vms=("${still_failing[@]}")
        
        # Check if all VMs are ready
        if [[ ${#remaining_vms[@]} -eq 0 ]]; then
            local total_time=$((current_time - start_time))
            log "SUCCESS" "All VMs SSH ready after ${total_time}s (attempt $attempt)"
            echo -e "${GREEN}🎉 All VMs have SSH connectivity!${NC}"
            return 0
        fi
        
        # Calculate delay for next attempt
        local delay; delay=$(calculate_delay "$attempt")
        log "INFO" "Waiting ${delay}s before next attempt (${#remaining_vms[@]} VMs still pending)"
        sleep "$delay"
    done
    
    # Final failure report
    log "ERROR" "SSH readiness check failed after $MAX_ATTEMPTS attempts"
    echo -e "${RED}❌ SSH readiness check failed for ${#remaining_vms[@]} VMs:${NC}"
    for vm_info in "${remaining_vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        echo -e "${RED}  - $vm_name ($vm_ip)${NC}"
    done
    
    return 1
}

# Function to generate SSH readiness report
generate_ssh_report() {
    local vms=("$@")
    local report_file="/tmp/ssh-readiness-report.txt"
    
    echo "=== SSH Readiness Report ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "Total VMs: ${#vms[@]}" >> "$report_file"
    echo "" >> "$report_file"
    
    for vm_info in "${vms[@]}"; do
        IFS='|' read -r vm_ip vm_name <<< "$vm_info"
        echo "VM: $vm_name ($vm_ip)" >> "$report_file"
        
        # Test final SSH status
        if test_ssh_connectivity "$vm_ip" "$vm_name" "final" 2>/dev/null; then
            echo "  SSH Status: READY" >> "$report_file"
        else
            echo "  SSH Status: NOT READY" >> "$report_file"
        fi
        
        # Test ping status
        if ping -c 1 -W 5 "$vm_ip" >/dev/null 2>&1; then
            echo "  Ping Status: REACHABLE" >> "$report_file"
        else
            echo "  Ping Status: NOT REACHABLE" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    echo "Report saved to: $report_file"
    echo "SSH_LOG_FILE=$report_file" >> "$GITHUB_ENV"
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

log "INFO" "Starting SSH readiness gate for ${#vms[@]} VMs"
log "INFO" "Configuration: MAX_ATTEMPTS=$MAX_ATTEMPTS, BASE_DELAY=$BASE_DELAY, MAX_DELAY=$MAX_DELAY, TIMEOUT=$TIMEOUT, SSH_TIMEOUT=$SSH_TIMEOUT"

# First, do a parallel check to see current status
echo -e "${BLUE}🔍 Initial parallel SSH check...${NC}"
if test_ssh_parallel "${vms[@]}" >/dev/null; then
    echo -e "${GREEN}🎉 All VMs already have SSH connectivity!${NC}"
    generate_ssh_report "${vms[@]}"
    exit 0
fi

# Wait for remaining VMs
echo -e "${BLUE}⏳ Waiting for remaining VMs...${NC}"
if wait_for_ssh "${vms[@]}"; then
    generate_ssh_report "${vms[@]}"
    exit 0
else
    generate_ssh_report "${vms[@]}"
    exit 1
fi
