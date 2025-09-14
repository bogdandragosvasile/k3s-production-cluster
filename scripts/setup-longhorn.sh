#!/bin/bash

# Longhorn Distributed Storage Setup Script
# This script installs and configures Longhorn for the K3s cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LONGHORN_VERSION="1.6.0"
STORAGE_CLASS="longhorn"
REPLICAS=3

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

# Install Longhorn
install_longhorn() {
    log_info "Installing Longhorn $LONGHORN_VERSION"
    
    # Add Longhorn Helm repository
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    
    # Create Longhorn namespace
    kubectl create namespace longhorn-system --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Longhorn with essential configuration
    helm install longhorn longhorn/longhorn \
        --namespace longhorn-system \
        --version $LONGHORN_VERSION \
        --set persistence.defaultClassReplicaCount=$REPLICAS \
        --set persistence.defaultClass=false \
        --set defaultSettings.defaultDataPath="/var/lib/longhorn/" \
        --set defaultSettings.defaultDataLocality="strict-local" \
        --set defaultSettings.replicaSoftAntiAffinity=true \
        --set defaultSettings.replicaAutoBalance="least-effort" \
        --set defaultSettings.storageOverProvisioningPercentage=200 \
        --set defaultSettings.storageMinimalAvailablePercentage=10 \
        --set defaultSettings.upgradeChecker=false \
        --set defaultSettings.defaultReplicaCount=$REPLICAS \
        --set defaultSettings.guaranteedEngineManagerCPU=0.25 \
        --set defaultSettings.guaranteedReplicaManagerCPU=0.25 \
        --set defaultSettings.allowRecurringJobWhileVolumeDetached=true \
        --set defaultSettings.autoSalvage=true \
        --set defaultSettings.autoDeletePodWhenVolumeDetachedUnexpectedly=true \
        --set defaultSettings.detachManuallyAttachedVolumesWhenCordonNode=true \
        --set defaultSettings.replicaDiskSoftAntiAffinity=true \
        --set defaultSettings.nodeDownPodDeletionPolicy="delete-both-statefulset-and-deployment-pod" \
        --set defaultSettings.autoCleanupSystemGeneratedSnapshot=true \
        --set defaultSettings.kubeletRootDir="/var/lib/kubelet" \
        --set defaultSettings.offlineReplicaRebuilding=false \
        --set defaultSettings.concurrentReplicaRebuildPerNodeLimit=5 \
        --set defaultSettings.concurrentVolumeBackupRestorePerNodeLimit=5 \
        --set defaultSettings.logLevel=info \
        --set defaultSettings.backupCompressionMethod=lz4 \
        --set defaultSettings.backupConcurrentLimit=2 \
        --set defaultSettings.restoreConcurrentLimit=2
    
    log_success "Longhorn installed successfully"
}

# Wait for Longhorn to be ready
wait_for_longhorn() {
    log_info "Waiting for Longhorn to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s deployment/longhorn-manager -n longhorn-system
    kubectl wait --for=condition=ready --timeout=300s pod -l app=longhorn-manager -n longhorn-system
    
    log_success "Longhorn is ready"
}

# Create StorageClass
create_storage_class() {
    log_info "Creating Longhorn StorageClass"
    
    cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: $STORAGE_CLASS
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "$REPLICAS"
  staleReplicaTimeout: "2880"
  fromBackup: ""
  fsType: "ext4"
  dataLocality: "strict-local"
  replicaSoftAntiAffinity: "true"
  replicaAutoBalance: "least-effort"
EOF
    
    log_success "StorageClass created"
}

# Verify installation
verify_installation() {
    log_info "Verifying Longhorn installation"
    
    # Check pods
    kubectl get pods -n longhorn-system
    
    # Check storage class
    kubectl get storageclass
    
    # Check nodes
    kubectl get nodes -o wide
    
    log_success "Longhorn verification completed"
}

# Main function
main() {
    log_info "Starting Longhorn Setup"
    log_info "======================"
    
    install_longhorn
    wait_for_longhorn
    create_storage_class
    verify_installation
    
    log_success "Longhorn Setup Completed!"
    log_info "Longhorn UI will be available at: http://longhorn-ui.longhorn-system.svc.cluster.local:9000"
    log_info "Default StorageClass: $STORAGE_CLASS"
    log_info "Replicas: $REPLICAS"
}

# Run main function
main "$@"
