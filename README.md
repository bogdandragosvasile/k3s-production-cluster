# K3s Production Cluster

A highly available K3s cluster deployed on KVM with distributed storage (Longhorn) and load balancing (MetalLB). This setup is inspired by the [k8s-libvirt-cluster](https://github.com/bogdandragosvasile/k8s-libvirt-cluster) repository and provides a robust, production-ready Kubernetes environment.

## 🏗️ Architecture

### Cluster Configuration
- **3 Master Nodes**: 4GB RAM, 2 vCPU each
- **3 Worker Nodes**: 8GB RAM, 4 vCPU each  
- **2 Storage Nodes**: 4GB RAM, 2 vCPU each
- **2 Load Balancer Nodes**: 1GB RAM, 1 vCPU each

### Network Configuration
- **Network**: Default libvirt network (192.168.122.0/24)
- **Gateway**: 192.168.122.1
- **DNS**: 8.8.8.8, 8.8.4.4
- **Static IPs**: 192.168.122.11-42

### Storage & Load Balancing
- **Distributed Storage**: Longhorn (3 replicas)
- **Load Balancing**: MetalLB (192.168.122.100-150 range)
- **Ingress**: Traefik (built into K3s)

## 🚀 Quick Start

### Prerequisites

1. **System Requirements**:
   - Ubuntu 24.04 LTS host
   - KVM/QEMU support
   - Libvirt installed and configured
   - At least 32GB RAM and 200GB storage

2. **Required Software**:
   ```bash
   # Install required packages
   sudo apt update
   sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
   sudo apt install -y terraform ansible jq
   
   # Add user to libvirt group
   sudo usermod -aG libvirt $USER
   newgrp libvirt
   ```

3. **Download Base Image**:
   ```bash
   # Download Ubuntu 24.04 LTS cloud image
   wget https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img \
        -O /var/lib/libvirt/images/ubuntu-24.04-cloudimg-amd64.img
   ```

4. **Generate SSH Key**:
   ```bash
   # Generate SSH key for cluster access
   ssh-keygen -t ed25519 -f ~/.ssh/k3s-cluster -C 'k3s-cluster@production'
   ```

### Deployment

1. **Clone Repository**:
   ```bash
   git clone <repository-url>
   cd k3s-production-cluster
   ```

2. **Deploy Cluster**:
   ```bash
   # Run the comprehensive deployment script
   ./scripts/deploy-k3s-cluster.sh
   ```

3. **Verify Deployment**:
   ```bash
   # Check cluster status
   kubectl get nodes
   kubectl get pods --all-namespaces
   
   # Check Longhorn
   kubectl get pods -n longhorn-system
   
   # Check MetalLB
   kubectl get pods -n metallb-system
   ```

## 📁 Project Structure

```
k3s-production-cluster/
├── ansible/                    # Ansible playbooks and roles
│   ├── inventory.yml          # Generated inventory file
│   ├── ansible.cfg            # Ansible configuration
│   └── playbooks/             # K3s, Longhorn, MetalLB playbooks
├── configs/                    # Cluster configuration files
│   └── cluster-config.yaml    # K3s cluster configuration
├── scripts/                    # Deployment and utility scripts
│   ├── deploy-k3s-cluster.sh  # Main deployment script
│   ├── cleanup-cluster.sh     # Comprehensive cleanup script
│   └── setup-*.sh             # Individual component scripts
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Main Terraform configuration
│   ├── variables.tf           # Terraform variables
│   ├── outputs.tf             # Terraform outputs
│   └── templates/              # Cloud-init templates
└── docs/                       # Documentation
    └── deployment-guide.md    # Detailed deployment guide
```

## 🔧 Configuration

### Cluster Configuration
Edit `configs/cluster-config.yaml` to customize:
- Cluster name and version
- Network CIDRs
- Load balancer VIP and range
- Node counts and resources

### Terraform Variables
Edit `terraform/variables.tf` to customize:
- Base image path
- SSH public key
- Network configuration
- Node specifications

### Ansible Configuration
Edit `ansible/ansible.cfg` to customize:
- SSH settings
- Inventory location
- Playbook execution options

## 🛠️ Management Commands

### Deploy Cluster
```bash
./scripts/deploy-k3s-cluster.sh
```

### Clean Up Cluster
```bash
./scripts/cleanup-cluster.sh
```

### Individual Component Deployment
```bash
# Deploy infrastructure only
cd terraform && terraform apply

# Deploy K3s cluster
cd ansible && ansible-playbook -i inventory.yml playbooks/k3s-cluster.yml

# Deploy Longhorn
cd ansible && ansible-playbook -i inventory.yml playbooks/longhorn.yml

# Deploy MetalLB
cd ansible && ansible-playbook -i inventory.yml playbooks/metallb.yml
```

### Access VMs
```bash
# SSH to master node
ssh -i ~/.ssh/k3s-cluster ubuntu@192.168.122.11

# SSH to worker node
ssh -i ~/.ssh/k3s-cluster ubuntu@192.168.122.21
```

## 🔍 Troubleshooting

### Common Issues

1. **VM Creation Fails**:
   - Check libvirt permissions
   - Verify base image exists
   - Check available disk space

2. **SSH Connection Fails**:
   - Wait for cloud-init to complete
   - Check VM status: `sudo virsh list --all`
   - Verify SSH key configuration

3. **K3s Installation Fails**:
   - Check VM connectivity
   - Verify Ansible inventory
   - Check system requirements

4. **Longhorn/MetalLB Issues**:
   - Check cluster connectivity
   - Verify node labels
   - Check resource availability

### Debug Commands

```bash
# Check VM status
sudo virsh list --all

# Check VM console
sudo virsh console <vm-name>

# Check libvirt logs
sudo journalctl -u libvirtd

# Check Ansible connectivity
ansible all -m ping

# Check K3s status
kubectl get nodes
kubectl describe nodes
```

## 📊 Monitoring

### Cluster Health
```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl get pods --all-namespaces

# Check cluster events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### Storage Monitoring
```bash
# Check Longhorn status
kubectl get pods -n longhorn-system
kubectl get pv
kubectl get pvc

# Check storage usage
kubectl top nodes
kubectl top pods --all-namespaces
```

### Load Balancer Monitoring
```bash
# Check MetalLB status
kubectl get pods -n metallb-system
kubectl get svc --all-namespaces

# Check load balancer configuration
kubectl get configmap -n metallb-system
```

## 🔒 Security

### SSH Access
- Uses ED25519 SSH keys
- Password authentication disabled
- Key-based access only

### Network Security
- Isolated libvirt network
- No external network exposure by default
- Firewall rules as needed

### Kubernetes Security
- RBAC enabled
- Network policies supported
- Pod security standards

## 🚀 Production Considerations

### High Availability
- 3 master nodes for quorum
- Distributed storage with replication
- Load balancer redundancy

### Scalability
- Easy to add worker nodes
- Horizontal pod autoscaling
- Resource quotas and limits

### Backup & Recovery
- Longhorn backup capabilities
- VM snapshot support
- Configuration version control

## 📚 Additional Resources

- [K3s Documentation](https://k3s.io/)
- [Longhorn Documentation](https://longhorn.io/docs/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest)
- [Ansible Documentation](https://docs.ansible.com/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Inspired by [k8s-libvirt-cluster](https://github.com/bogdandragosvasile/k8s-libvirt-cluster)
- Built with [K3s](https://k3s.io/), [Longhorn](https://longhorn.io/), and [MetalLB](https://metallb.universe.tf/)
- Infrastructure managed with [Terraform](https://terraform.io/) and [Ansible](https://ansible.com/)