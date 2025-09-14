# K3s Production Cluster

A complete Infrastructure as Code (IaC) solution for deploying a production-ready K3s cluster using Terraform, Ansible, and GitHub Actions.

## 🏗️ Architecture

### Infrastructure Components
- **3 Master Nodes**: High availability control plane
- **6 Worker Nodes**: Application workload execution
- **2 Storage Nodes**: Dedicated storage for Longhorn
- **2 Load Balancer Nodes**: Traffic distribution
- **1 GPU Node**: GPU-accelerated workloads

### Technology Stack
- **Infrastructure**: Terraform + libvirt
- **Configuration**: Ansible
- **Orchestration**: K3s (lightweight Kubernetes)
- **CI/CD**: GitHub Actions with self-hosted runner
- **Storage**: Longhorn (distributed storage)
- **Load Balancing**: MetalLB
- **Monitoring**: Prometheus + Grafana (ready)

## 🚀 Quick Start

### Prerequisites
- Ubuntu 24.04 LTS hypervisor
- libvirt/KVM installed and configured
- GitHub Actions self-hosted runner
- SSH key pair (`~/.ssh/id_rsa`)

### Deploy Cluster
1. **Manual Deployment**:
   ```bash
   # Deploy infrastructure
   cd terraform
   terraform init
   terraform apply
   
   # Deploy K3s cluster
   cd ../ansible
   ansible-playbook -i inventory.yml playbooks/install-k3s.yaml
   ```

2. **CI/CD Deployment**:
   - Go to GitHub Actions → "Deploy K3s Production Cluster"
   - Click "Run workflow" → "Run workflow"

### Cleanup Cluster
1. **Manual Cleanup**:
   ```bash
   # Destroy with Terraform
   cd terraform
   terraform destroy
   
   # Manual cleanup
   for vm in $(virsh list --all --name | grep k3s-production); do
     virsh destroy $vm 2>/dev/null || true
     virsh undefine $vm --remove-all-storage 2>/dev/null || true
   done
   ```

2. **CI/CD Cleanup**:
   - Go to GitHub Actions → "Cleanup K3s Production Cluster"
   - Click "Run workflow"
   - Type "DESTROY" to confirm
   - Click "Run workflow"

## 📋 GitHub Actions Workflows

### 1. Deploy Workflow (`deploy.yml`)
**Triggers**: Push to main, Manual dispatch

**Steps**:
1. **Infrastructure Deployment**:
   - Clean up existing VMs
   - Initialize Terraform
   - Plan and apply infrastructure
   - Generate Ansible inventory

2. **K3s Cluster Deployment**:
   - Wait for VMs to be ready
   - Fix repository issues
   - Deploy K3s cluster
   - Setup kubectl
   - Validate cluster

3. **Notification**:
   - Success/failure notifications

### 2. Cleanup Workflow (`cleanup.yml`)
**Triggers**: Manual dispatch, Scheduled (optional)

**Steps**:
1. **Verification**: Confirm destruction with "DESTROY"
2. **VM Cleanup**: Stop and undefine all VMs
3. **Volume Cleanup**: Remove all associated volumes
4. **Network Cleanup**: Destroy pools and networks
5. **State Cleanup**: Clean Terraform state and SSH known hosts
6. **Verification**: Confirm complete cleanup

## 🔧 Configuration

### Network Configuration
- **CIDR**: 192.168.122.0/24
- **Master IPs**: 192.168.122.11-13
- **Worker IPs**: 192.168.122.21-26
- **Storage IPs**: 192.168.122.31-32
- **Load Balancer IPs**: 192.168.122.41-42
- **GPU IP**: 192.168.122.51

### VM Specifications
- **Masters**: 2 vCPU, 4GB RAM, 20GB disk
- **Workers**: 4 vCPU, 8GB RAM, 30GB disk
- **Storage**: 2 vCPU, 4GB RAM, 20GB disk
- **Load Balancers**: 1 vCPU, 1GB RAM, 10GB disk
- **GPU**: 4 vCPU, 8GB RAM, 30GB disk

## 🛠️ Customization

### Adding Nodes
1. Update `terraform/variables.tf`:
   ```hcl
   variable "worker_count" {
     default = 8  # Increase from 6
   }
   ```

2. Update IP ranges in `terraform/main.tf`

3. Run deployment workflow

### Changing K3s Version
1. Update `ansible/playbooks/install-k3s.yaml`:
   ```yaml
   K3S_VERSION: "v1.33.4+k3s1"  # Change version
   ```

2. Run deployment workflow

### Adding Storage
1. Update `terraform/variables.tf`:
   ```hcl
   variable "storage_count" {
     default = 4  # Increase from 2
   }
   ```

2. Run deployment workflow

## 🔍 Monitoring and Validation

### Cluster Health Check
```bash
# Get kubeconfig
scp ubuntu@192.168.122.11:/etc/rancher/k3s/k3s.yaml ./kubeconfig
sed -i "s/127.0.0.1/192.168.122.11/g" kubeconfig
export KUBECONFIG=./kubeconfig

# Check cluster status
kubectl get nodes
kubectl get pods -A
kubectl get services
```

### Access Cluster
```bash
# SSH to master node
ssh ubuntu@192.168.122.11

# Check K3s status
sudo systemctl status k3s
sudo k3s kubectl get nodes
```

## 🚨 Troubleshooting

### Common Issues

1. **VM Creation Fails**:
   - Check libvirt permissions
   - Verify base image exists
   - Check available disk space

2. **SSH Connection Fails**:
   - Verify SSH key is correct
   - Check VM is running
   - Remove old host keys: `ssh-keygen -R <ip>`

3. **Ansible Playbook Fails**:
   - Check inventory file
   - Verify SSH connectivity
   - Check package repositories

4. **K3s Installation Fails**:
   - Check VM resources
   - Verify network connectivity
   - Check system requirements

### Logs and Debugging
```bash
# Check VM logs
virsh console <vm-name>

# Check K3s logs
sudo journalctl -u k3s -f

# Check Ansible logs
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml -vvv
```

## 📚 Additional Resources

- [K3s Documentation](https://k3s.io/)
- [Terraform libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest)
- [Ansible Documentation](https://docs.ansible.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review GitHub Issues
3. Create a new issue with detailed information

---

**⚠️ Important**: This is a production-ready setup. Always test in a development environment first and ensure you have proper backups before deploying to production.