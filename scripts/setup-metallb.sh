#!/bin/bash

# MetalLB Load Balancer Setup Script
# This script installs and configures MetalLB for the K3s cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
METALLB_VERSION="0.13.12"
IP_POOL_NAME="production"
IP_RANGE="192.168.1.11-192.168.1.20"  # Using your static pool

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install MetalLB
install_metallb() {
    log_info "Installing MetalLB $METALLB_VERSION"
    
    # Apply MetalLB manifest
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$METALLB_VERSION/config/manifests/metallb-native.yaml
    
    log_success "MetalLB installed successfully"
}

# Wait for MetalLB to be ready
wait_for_metallb() {
    log_info "Waiting for MetalLB to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/controller -n metallb-system
    kubectl wait --for=condition=ready --timeout=300s pod -l app=metallb -n metallb-system
    
    log_success "MetalLB is ready"
}

# Configure IP Address Pool
configure_ip_pool() {
    log_info "Configuring IP address pool: $IP_RANGE"
    
    cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: $IP_POOL_NAME
  namespace: metallb-system
spec:
  addresses:
  - $IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: $IP_POOL_NAME
  namespace: metallb-system
spec:
  ipAddressPools:
  - $IP_POOL_NAME
EOF
    
    log_success "IP address pool configured"
}

# Verify installation
verify_installation() {
    log_info "Verifying MetalLB installation"
    
    # Check pods
    kubectl get pods -n metallb-system
    
    # Check IP address pool
    kubectl get ipaddresspools -n metallb-system
    
    # Check L2 advertisement
    kubectl get l2advertisements -n metallb-system
    
    log_success "MetalLB verification completed"
}

# Test with a sample service
test_load_balancer() {
    log_info "Testing MetalLB with a sample service"
    
    # Create a test deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  labels:
    app: test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: test-app-service
  annotations:
    metallb.universe.tf/allow-shared-ip: "test"
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
EOF
    
    # Wait for external IP
    log_info "Waiting for external IP assignment..."
    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' --timeout=60s service/test-app-service
    
    # Get the external IP
    local external_ip=$(kubectl get service test-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    log_success "Test service got external IP: $external_ip"
    
    # Test connectivity
    log_info "Testing connectivity to $external_ip"
    if curl -s --max-time 10 "http://$external_ip" > /dev/null; then
        log_success "Load balancer test successful"
    else
        log_warning "Load balancer test failed - this might be normal if the service is still starting"
    fi
    
    # Clean up test resources
    kubectl delete deployment test-app
    kubectl delete service test-app-service
    
    log_success "Test completed and cleaned up"
}

# Main function
main() {
    log_info "Starting MetalLB Setup"
    log_info "======================"
    
    install_metallb
    wait_for_metallb
    configure_ip_pool
    verify_installation
    test_load_balancer
    
    log_success "MetalLB Setup Completed!"
    log_info "IP Address Pool: $IP_RANGE"
    log_info "LoadBalancer services will get IPs from: $IP_RANGE"
}

# Run main function
main "$@"
