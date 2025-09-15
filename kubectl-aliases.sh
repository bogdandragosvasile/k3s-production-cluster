#!/bin/bash

# K3s kubectl aliases for different access methods

# Original direct access
alias kubectl-original='KUBECONFIG=./kubeconfig-fresh.yaml kubectl'

# HA Load Balancer access (default)
alias kubectl-ha='KUBECONFIG=./kubeconfig-ha.yaml kubectl --insecure-skip-tls-verify'

# Direct master access
alias kubectl-master1='KUBECONFIG=./kubeconfig-fresh.yaml kubectl --server=https://192.168.122.11:6443'
alias kubectl-master2='KUBECONFIG=./kubeconfig-fresh.yaml kubectl --server=https://192.168.122.12:6443'
alias kubectl-master3='KUBECONFIG=./kubeconfig-fresh.yaml kubectl --server=https://192.168.122.13:6443'

# Load balancer access
alias kubectl-lb1='KUBECONFIG=./kubeconfig-ha.yaml kubectl --server=https://192.168.122.41:6443 --insecure-skip-tls-verify'
alias kubectl-lb2='KUBECONFIG=./kubeconfig-ha.yaml kubectl --server=https://192.168.122.42:6443 --insecure-skip-tls-verify'

# Quick status check
alias k8s-status='kubectl-ha get nodes && echo "---" && kubectl-ha get pods -A'

echo "Kubectl aliases loaded:"
echo "  kubectl-ha     - HA Load Balancer access (default)"
echo "  kubectl-original - Direct master access"
echo "  kubectl-master1/2/3 - Direct master access"
echo "  kubectl-lb1/2  - Direct LB access"
echo "  k8s-status     - Quick cluster status"
