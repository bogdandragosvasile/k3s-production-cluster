#!/bin/bash
# Fix kubeconfig for K3s cluster

set -e

echo "🔧 Fixing kubeconfig for K3s cluster..."

# Get the master node IP (first master)
MASTER_IP="192.168.122.11"

# Copy kubeconfig from master node
echo "📥 Downloading kubeconfig from master node..."
ssh -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "sudo cp /etc/rancher/k3s/k3s.yaml /tmp/k3s.yaml && sudo chown ubuntu:ubuntu /tmp/k3s.yaml"

# Copy to local ansible directory
scp -o StrictHostKeyChecking=no ubuntu@$MASTER_IP:/tmp/k3s.yaml ansible/kubeconfig

# Update server address
echo "🔧 Updating kubeconfig server address..."
sed -i 's/127\.0\.0\.1/'$MASTER_IP'/g' ansible/kubeconfig

# Set correct permissions
chmod 600 ansible/kubeconfig

# Test kubeconfig
echo "🧪 Testing kubeconfig..."
cd ansible
kubectl --kubeconfig=kubeconfig get nodes

echo "✅ Kubeconfig fixed successfully!"
echo "📋 Cluster info:"
kubectl --kubeconfig=kubeconfig cluster-info
