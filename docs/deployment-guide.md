# K3s Production Cluster Deployment Guide

This guide walks you through deploying a production-ready K3s cluster on your KVM infrastructure.

## 🏗️ Network Configuration

Your cluster is configured for your network:
- **LAN**: 192.168.1.0/24
- **Gateway**: 192.168.1.1
- **Static Pool**: 192.168.1.2-192.168.1.49 (used by cluster)
- **Dynamic Pool**: 192.168.1.254 (available for other devices)

### Cluster IP Allocation
- **Control Plane**: 192.168.1.10-192.168.1.12
- **Worker Nodes**: 192.168.1.20-192.168.1.26
- **Storage Nodes**: 192.168.1.30-192.168.1.31
- **Load Balancers**: 192.168.1.40-192.168.1.41
- **GPU Node**: 192.168.1.50
- **MetalLB Pool**: 192.168.1.11-192.168.1.20

## 🚀 Step-by-Step Deployment

### Prerequisites
- Ubuntu 24.04 LTS host with KVM/QEMU
- 2.3TB storage available
- 120GB+ RAM available
- 256 CPU cores available
- Internet connection for downloading images

### Step 1: Prepare the Environment

```bash
# Navigate to the project directory
cd k3s-production-cluster

# Ensure you have the required tools
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager

# Start libvirt service
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
```

### Step 2: Deploy VMs

```bash
# Deploy all VMs (this will take some time)
sudo ./scripts/deploy-cluster.sh
```

This script will:
- Download Ubuntu 24.04 LTS ISO
- Create VM templates
- Deploy 14 VMs (3 masters + 7 workers + 2 storage + 2 LB + 1 GPU)
- Configure networking

**Note**: You'll need to complete Ubuntu installation on each VM via VNC during this process.

### Step 3: Install K3s

```bash
# Install K3s on all VMs
./scripts/setup-k3s-cluster.sh
```

This script will:
- Install K3s on all VMs
- Configure the cluster
- Set up kubectl access
- Label nodes appropriately

### Step 4: Install Longhorn Storage

```bash
# Install distributed storage
./scripts/setup-longhorn.sh
```

This script will:
- Install Longhorn distributed storage
- Configure 3 replicas for data safety
- Set up default StorageClass

### Step 5: Install MetalLB Load Balancer

```bash
# Install load balancer
./scripts/setup-metallb.sh
```

This script will:
- Install MetalLB
- Configure IP address pool (192.168.1.11-192.168.1.20)
- Test load balancing functionality

## 🔧 Post-Deployment Configuration

### Access the Cluster

```bash
# Check cluster status
kubectl get nodes -o wide

# Check all pods
kubectl get pods -A

# Check storage classes
kubectl get storageclass
```

### Access Services

- **K3s API**: https://192.168.1.10:6443
- **Longhorn UI**: http://192.168.1.11:9000 (after port-forward)
- **Traefik Dashboard**: http://traefik.k3s.local (after DNS setup)

### Port Forwarding for Web UIs

```bash
# Longhorn UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 9000:80

# Access at: http://localhost:9000
```

## 📊 Cluster Management

### Scale Worker Nodes

```bash
# Scale to 9 worker nodes
./scripts/scale-workers.sh 9
```

### Backup Cluster

```bash
# Create cluster backup
./scripts/backup-cluster.sh
```

### Update Cluster

```bash
# Update K3s version
./scripts/update-cluster.sh
```

## 🎯 Testing Your Cluster

### Deploy a Test Application

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --type=LoadBalancer

# Check external IP
kubectl get service nginx

# Test connectivity
curl http://<EXTERNAL_IP>
```

### Deploy with Persistent Storage

```bash
# Create a PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: longhorn
EOF

# Deploy app with PVC
kubectl create deployment test-app --image=nginx:alpine
kubectl set volume deployment/test-app --name=test-volume --mount-path=/data --claim-name=test-pvc
```

## 🔍 Troubleshooting

### Check VM Status

```bash
# List all VMs
virsh list --all

# Check VM console
virsh console k3s-master-1

# Restart VM
virsh start k3s-master-1
```

### Check Cluster Health

```bash
# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -A

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Check Storage

```bash
# Check Longhorn status
kubectl get pods -n longhorn-system

# Check PVCs
kubectl get pvc

# Check PVs
kubectl get pv
```

### Check Load Balancing

```bash
# Check MetalLB status
kubectl get pods -n metallb-system

# Check IP address pools
kubectl get ipaddresspools -n metallb-system

# Check services
kubectl get services
```

## 📈 Monitoring

### Install Monitoring Stack

```bash
# Install Prometheus and Grafana
./scripts/setup-monitoring.sh
```

### Access Monitoring

- **Grafana**: http://grafana.k3s.local
- **Prometheus**: http://prometheus.k3s.local

## 🔒 Security

### Enable Network Policies

```bash
# Install Calico for network policies
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
```

### Enable Pod Security Standards

```bash
# Apply restricted pod security
kubectl label namespace default pod-security.kubernetes.io/enforce=restricted
```

## 🎉 Success!

Your K3s production cluster is now ready! You have:

- ✅ 3-master HA control plane
- ✅ 7 worker nodes for workloads
- ✅ 2 storage nodes with Longhorn
- ✅ 2 load balancers for HA
- ✅ 1 GPU node for ML/AI workloads
- ✅ Distributed storage with 3 replicas
- ✅ Load balancing with external IPs
- ✅ Monitoring and backup capabilities

## 📚 Next Steps

1. **Deploy your applications** using the cluster
2. **Set up monitoring** for production workloads
3. **Configure backups** for data protection
4. **Implement security policies** for production use
5. **Scale resources** as needed

## 🆘 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review the logs: `kubectl logs <pod-name> -n <namespace>`
3. Check VM status: `virsh list --all`
4. Review the documentation in the `docs/` directory
