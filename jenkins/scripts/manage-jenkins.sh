#!/bin/bash

# Jenkins Management Script for K3s Production Cluster
# This script provides easy management of Jenkins services

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
JENKINS_DIR="/home/bogdan/GitHub/k3s-production-cluster/jenkins/docker"
JENKINS_URL="http://localhost:8080"

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show usage
show_usage() {
    echo "Jenkins Management Script for K3s Production Cluster"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  start       Start Jenkins services"
    echo "  stop        Stop Jenkins services"
    echo "  restart     Restart Jenkins services"
    echo "  status      Show Jenkins services status"
    echo "  logs        Show Jenkins logs"
    echo "  build       Build Jenkins agent image"
    echo "  health      Check Jenkins health"
    echo "  help        Show this help message"
}

# Start Jenkins services
start_jenkins() {
    log "Starting Jenkins services..."
    cd "$JENKINS_DIR"
    docker-compose up -d
    log_success "Jenkins services started"
}

# Stop Jenkins services
stop_jenkins() {
    log "Stopping Jenkins services..."
    cd "$JENKINS_DIR"
    docker-compose down
    log_success "Jenkins services stopped"
}

# Restart Jenkins services
restart_jenkins() {
    log "Restarting Jenkins services..."
    cd "$JENKINS_DIR"
    docker-compose restart
    log_success "Jenkins services restarted"
}

# Show status
show_status() {
    log "Jenkins services status:"
    cd "$JENKINS_DIR"
    docker-compose ps
    echo ""
    
    # Check if Jenkins is accessible
    if curl -s "$JENKINS_URL" > /dev/null 2>&1; then
        log_success "Jenkins is accessible at $JENKINS_URL"
    else
        log_warning "Jenkins is not accessible at $JENKINS_URL"
    fi
}

# Show logs
show_logs() {
    log "Showing Jenkins logs..."
    cd "$JENKINS_DIR"
    docker-compose logs -f
}

# Build agent image
build_agent() {
    log "Building Jenkins agent image..."
    cd "$JENKINS_DIR"
    docker build -t k3s-jenkins-agent:latest .
    log_success "Jenkins agent image built"
}

# Check health
check_health() {
    log "Checking Jenkins health..."
    
    # Check if containers are running
    cd "$JENKINS_DIR"
    if docker-compose ps | grep -q "Up"; then
        log_success "Jenkins containers are running"
    else
        log_error "Jenkins containers are not running"
        return 1
    fi
    
    # Check if Jenkins is accessible
    if curl -s "$JENKINS_URL" > /dev/null 2>&1; then
        log_success "Jenkins is accessible"
    else
        log_error "Jenkins is not accessible"
        return 1
    fi
    
    # Check workspace
    if [ -d "/home/bogdan/GitHub/k3s-production-cluster" ]; then
        log_success "Workspace is accessible"
    else
        log_error "Workspace not found"
        return 1
    fi
}

# Main function
main() {
    case "${1:-help}" in
        start)
            start_jenkins
            ;;
        stop)
            stop_jenkins
            ;;
        restart)
            restart_jenkins
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        build)
            build_agent
            ;;
        health)
            check_health
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
