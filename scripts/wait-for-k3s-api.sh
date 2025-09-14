#!/bin/bash
set -euo pipefail

# K3s Production Cluster - K3s API Readiness Gate
# Waits for K3s API server to be ready with /readyz and /healthz endpoint checks

echo "🚀 K3s API Readiness Gate - Starting API server health checks..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_ATTEMPTS=${MAX_ATTEMPTS:-40}
BASE_DELAY=${BASE_DELAY:-5}
MAX_DELAY=${MAX_DELAY:-30}
TIMEOUT=${TIMEOUT:-600}  # 10 minutes total timeout
API_TIMEOUT=${API_TIMEOUT:-10}  # Individual API call timeout
LOG_FILE=${LOG_FILE:-/tmp/k3s-api-readiness.log}

# Initialize log file
echo "=== K3s API Readiness Gate - $(date) ===" > "$LOG_FILE"

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

# Function to check K3s API health endpoints
check_k3s_api_health() {
    local server_ip=$1
    local server_name=$2
    local attempt=$3
    
    log "INFO" "Checking K3s API health on $server_name ($server_ip) - attempt $attempt"
    
    # Check if server is reachable first
    if ! ping -c 1 -W 5 "$server_ip" >/dev/null 2>&1; then
        log "WARN" "Server $server_name ($server_ip) not reachable via ping"
        return 1
    fi
    
    # Check if port 6443 is open
    if ! timeout 5 bash -c "echo > /dev/tcp/$server_ip/6443" 2>/dev/null; then
        log "WARN" "Port 6443 not open on $server_name ($server_ip)"
        return 1
    fi
    
    # Test /healthz endpoint
    local healthz_url="https://$server_ip:6443/healthz"
    local healthz_status=0
    
    if timeout "$API_TIMEOUT" curl -k -s -f "$healthz_url" >/dev/null 2>&1; then
        log "SUCCESS" "/healthz endpoint responding on $server_name ($server_ip)"
        healthz_status=1
    else
        log "WARN" "/healthz endpoint not responding on $server_name ($server_ip)"
    fi
    
    # Test /readyz endpoint
    local readyz_url="https://$server_ip:6443/readyz"
    local readyz_status=0
    
    if timeout "$API_TIMEOUT" curl -k -s -f "$readyz_url" >/dev/null 2>&1; then
        log "SUCCESS" "/readyz endpoint responding on $server_name ($server_ip)"
        readyz_status=1
    else
        log "WARN" "/readyz endpoint not responding on $server_name ($server_ip)"
    fi
    
    # Test kubectl connectivity
    local kubectl_status=0
    if timeout "$API_TIMEOUT" kubectl --kubeconfig=/tmp/k3s-kubeconfig get nodes >/dev/null 2>&1; then
        log "SUCCESS" "kubectl connectivity confirmed on $server_name ($server_ip)"
        kubectl_status=1
    else
        log "WARN" "kubectl connectivity failed on $server_name ($server_ip)"
    fi
    
    # All checks must pass
    if [[ $healthz_status -eq 1 && $readyz_status -eq 1 && $kubectl_status -eq 1 ]]; then
        log "SUCCESS" "All K3s API health checks passed on $server_name ($server_ip)"
        return 0
    else
        log "WARN" "K3s API health checks failed on $server_name ($server_ip) - attempt $attempt"
        return 1
    fi
}

# Function to check K3s API health in parallel
check_k3s_api_parallel() {
    local servers=("$@")
    local results=()
    local success_count=0
    local failed_count=0
    
    log "INFO" "Checking K3s API health on ${#servers[@]} servers in parallel"
    
    # Create temporary files for parallel execution
    local temp_dir; temp_dir=$(mktemp -d)
    local pids=()
    local server_index=0
    
    for server_info in "${servers[@]}"; do
        IFS='|' read -r server_ip server_name <<< "$server_info"
        local result_file="$temp_dir/result_$server_index"
        local server_file="$temp_dir/server_$server_index"
        echo "$server_info" > "$server_file"
        
        # Start background process for this server
        (
            if check_k3s_api_health "$server_ip" "$server_name" "parallel"; then
                echo "SUCCESS" > "$result_file"
            else
                echo "FAILED" > "$result_file"
            fi
        ) &
        
        pids+=($!)
        ((server_index++))
    done
    
    # Wait for all background processes to complete
    local timeout_duration=$((API_TIMEOUT + 10))
    
    for pid in "${pids[@]}"; do
        local wait_start; wait_start=$(date +%s)
        while kill -0 "$pid" 2>/dev/null; do
            local current_time; current_time=$(date +%s)
            local elapsed=$((current_time - wait_start))
            
            if [[ $elapsed -gt $timeout_duration ]]; then
                log "WARN" "K3s API test process $pid timed out after ${elapsed}s"
                kill -9 "$pid" 2>/dev/null || true
                break
            fi
            sleep 1
        done
        wait "$pid" 2>/dev/null || true
    done
    
    # Collect results
    server_index=0
    for server_info in "${servers[@]}"; do
        IFS='|' read -r server_ip server_name <<< "$server_info"
        local result_file="$temp_dir/result_$server_index"
        
        if [[ -f "$result_file" ]]; then
            local result; result=$(cat "$result_file")
            if [[ "$result" == "SUCCESS" ]]; then
                echo -e "${GREEN}✅ $server_name ($server_ip) - K3s API ready${NC}"
                ((success_count++))
                results+=("SUCCESS|$server_info")
            else
                echo -e "${YELLOW}⏳ $server_name ($server_ip) - K3s API not ready${NC}"
                ((failed_count++))
                results+=("FAILED|$server_info")
            fi
        else
            echo -e "${RED}❌ $server_name ($server_ip) - K3s API test failed${NC}"
            ((failed_count++))
            results+=("FAILED|$server_info")
        fi
        
        ((server_index++))
    done
    
    # Cleanup
    rm -rf "$temp_dir"
    
    log "INFO" "Parallel K3s API test complete: $success_count/${#servers[@]} servers ready"
    
    # Return results
    printf '%s\n' "${results[@]}"
    
    if [[ $failed_count -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to wait for K3s API with retries
wait_for_k3s_api() {
    local servers=("$@")
    local remaining_servers=("${servers[@]}")
    local start_time; start_time=$(date +%s)
    
    log "INFO" "Starting K3s API readiness wait for ${#servers[@]} servers"
    
    for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
        local current_time; current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $TIMEOUT ]]; then
            log "ERROR" "Timeout reached after ${elapsed}s (limit: ${TIMEOUT}s)"
            break
        fi
        
        log "INFO" "Attempt $attempt/$MAX_ATTEMPTS (elapsed: ${elapsed}s)"
        
        # Test remaining servers in parallel
        local results=()
        while IFS= read -r result_line; do
            results+=("$result_line")
        done < <(check_k3s_api_parallel "${remaining_servers[@]}")
        
        # Process results
        local still_failing=()
        for result_line in "${results[@]}"; do
            IFS='|' read -r status server_info <<< "$result_line"
            
            if [[ "$status" == "SUCCESS" ]]; then
                IFS='|' read -r server_ip server_name <<< "$server_info"
                echo -e "${GREEN}✅ $server_name ($server_ip) - K3s API ready${NC}"
            else
                still_failing+=("$server_info")
                IFS='|' read -r server_ip server_name <<< "$server_info"
                echo -e "${YELLOW}⏳ $server_name ($server_ip) - K3s API not ready${NC}"
            fi
        done
        
        # Update remaining servers
        remaining_servers=("${still_failing[@]}")
        
        # Check if all servers are ready
        if [[ ${#remaining_servers[@]} -eq 0 ]]; then
            local total_time=$((current_time - start_time))
            log "SUCCESS" "All K3s API servers ready after ${total_time}s (attempt $attempt)"
            echo -e "${GREEN}🎉 All K3s API servers are ready!${NC}"
            return 0
        fi
        
        # Calculate delay for next attempt
        local delay; delay=$(calculate_delay "$attempt")
        log "INFO" "Waiting ${delay}s before next attempt (${#remaining_servers[@]} servers still pending)"
        sleep "$delay"
    done
    
    # Final failure report
    log "ERROR" "K3s API readiness check failed after $MAX_ATTEMPTS attempts"
    echo -e "${RED}❌ K3s API readiness check failed for ${#remaining_servers[@]} servers:${NC}"
    for server_info in "${remaining_servers[@]}"; do
        IFS='|' read -r server_ip server_name <<< "$server_info"
        echo -e "${RED}  - $server_name ($server_ip)${NC}"
    done
    
    return 1
}

# Function to generate K3s API readiness report
generate_k3s_api_report() {
    local servers=("$@")
    local report_file="/tmp/k3s-api-readiness-report.txt"
    
    echo "=== K3s API Readiness Report ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "Total Servers: ${#servers[@]}" >> "$report_file"
    echo "" >> "$report_file"
    
    for server_info in "${servers[@]}"; do
        IFS='|' read -r server_ip server_name <<< "$server_info"
        echo "Server: $server_name ($server_ip)" >> "$report_file"
        
        # Check final status
        if check_k3s_api_health "$server_ip" "$server_name" "final" 2>/dev/null; then
            echo "  API Status: READY" >> "$report_file"
        else
            echo "  API Status: NOT READY" >> "$report_file"
        fi
        
        # Check port status
        if timeout 5 bash -c "echo > /dev/tcp/$server_ip/6443" 2>/dev/null; then
            echo "  Port 6443: OPEN" >> "$report_file"
        else
            echo "  Port 6443: CLOSED" >> "$report_file"
        fi
        echo "" >> "$report_file"
    done
    
    echo "Report saved to: $report_file"
    echo "K3S_API_LOG_FILE=$report_file" >> "$GITHUB_ENV"
}

# Main execution
if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <server_ip1>|<server_name1> [<server_ip2>|<server_name2> ...]"
    echo "Example: $0 192.168.122.11|master-1"
    exit 1
fi

# Parse server arguments
servers=()
for server_arg in "$@"; do
    if [[ "$server_arg" == *"|"* ]]; then
        servers+=("$server_arg")
    else
        echo -e "${RED}❌ Invalid server format: $server_arg (expected: ip|name)${NC}"
        exit 1
    fi
done

log "INFO" "Starting K3s API readiness gate for ${#servers[@]} servers"
log "INFO" "Configuration: MAX_ATTEMPTS=$MAX_ATTEMPTS, BASE_DELAY=$BASE_DELAY, MAX_DELAY=$MAX_DELAY, TIMEOUT=$TIMEOUT, API_TIMEOUT=$API_TIMEOUT"

# First, do a parallel check to see current status
echo -e "${BLUE}🔍 Initial parallel K3s API check...${NC}"
if check_k3s_api_parallel "${servers[@]}" >/dev/null; then
    echo -e "${GREEN}🎉 All K3s API servers already ready!${NC}"
    generate_k3s_api_report "${servers[@]}"
    exit 0
fi

# Wait for remaining servers
echo -e "${BLUE}⏳ Waiting for remaining servers...${NC}"
if wait_for_k3s_api "${servers[@]}"; then
    generate_k3s_api_report "${servers[@]}"
    exit 0
else
    generate_k3s_api_report "${servers[@]}"
    exit 1
fi
