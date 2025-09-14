#!/bin/bash
set -e

# Install K3s on first master
echo "Installing K3s on first master..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.11 "curl -sfL https://get.k3s.io | sh -s - server --cluster-init --disable traefik --disable servicelb"

# Get token from first master
echo "Getting K3s token..."
K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.11 "sudo cat /var/lib/rancher/k3s/server/node-token")

# Install K3s on other masters
echo "Installing K3s on other masters..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.12 "curl -sfL https://get.k3s.io | sh -s - server --server https://192.168.122.11:6443 --token $K3S_TOKEN --disable traefik --disable servicelb"
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.13 "curl -sfL https://get.k3s.io | sh -s - server --server https://192.168.122.11:6443 --token $K3S_TOKEN --disable traefik --disable servicelb"

# Install K3s on workers
echo "Installing K3s on workers..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.21 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.22 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.23 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"

# Install K3s on storage nodes
echo "Installing K3s on storage nodes..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.31 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.32 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"

# Install K3s on load balancers
echo "Installing K3s on load balancers..."
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.41 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"
ssh -o StrictHostKeyChecking=no ubuntu@192.168.122.42 "curl -sfL https://get.k3s.io | sh -s - agent --server https://192.168.122.11:6443 --token $K3S_TOKEN"

echo "K3s installation completed!"
