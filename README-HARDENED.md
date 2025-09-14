# K3s Production Cluster - Hardened Deployment

A production-ready K3s cluster deployment pipeline with comprehensive hardening, observability, and safety features.

## 🚀 Quick Start

### Prerequisites

- **Self-hosted GitHub Actions runner** with the following labels:
  - `self-hosted`
  - `libvirt`
  - `ubuntu-24.04`
- **Required tools** (automatically validated):
  - libvirt/KVM
  - Terraform >= 1.6.0
  - Ansible >= 2.15.0
  - kubectl
  - SSH key management

### Required Secrets

Configure the following repository secrets:

- `SSH_PRIVATE_KEY`: Private SSH key for cluster access (RSA 4096-bit recommended)

### Deployment

1. **Deploy the cluster:**
   ```bash
   # Trigger via GitHub Actions UI or API
   gh workflow run deploy-hardened.yml
   ```

2. **Monitor deployment:**
   ```bash
   gh run watch
   ```

3. **Download artifacts:**
   ```bash
   gh run download
   ```

## 🏗️ Architecture

### Workflow Structure

```
preflight → terraform-infra → ansible-bootstrap → k3s-control-plane → k3s-agents → validate-cluster
```

### Key Features

- **🔒 Security**: SSH key management via secrets, proper resource scoping
- **🛡️ Safety**: Concurrency controls, IP collision detection, safe cleanup
- **📊 Observability**: Comprehensive logging, health reports, artifact uploads
- **🔄 Reliability**: Robust readiness gates, idempotent operations
- **⚡ Performance**: Terraform caching, parallel operations where safe

## 📋 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TF_VERSION` | Terraform version | `1.6.0` |
| `ANSIBLE_VERSION` | Ansible version | `2.15.0` |
| `K3S_VERSION` | K3s version | `v1.33.4+k3s1` |
| `CLUSTER_NAME` | Cluster name | `k3s-production` |
| `ENVIRONMENT` | Environment | `production` |

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | Cluster name | `production` |
| `master_count` | Number of master nodes | `3` |
| `worker_count` | Number of worker nodes | `3` |
| `storage_count` | Number of storage nodes | `2` |
| `lb_count` | Number of load balancer nodes | `1` |
| `gpu_count` | Number of GPU nodes | `0` |

## 🔧 Troubleshooting

### Common Issues

#### 1. Preflight Checks Fail

**Symptoms**: Pipeline fails at preflight step

**Solutions**:
- Ensure runner has required labels: `self-hosted`, `libvirt`, `ubuntu-24.04`
- Verify libvirt daemon is running: `systemctl status libvirtd`
- Check user permissions: `groups | grep libvirt`
- Verify required tools are installed

#### 2. SSH Connectivity Issues

**Symptoms**: VMs created but Ansible can't connect

**Solutions**:
- Verify SSH private key is set in repository secrets
- Check VM IP addresses in inventory
- Ensure cloud-init completed: `cloud-init status --wait`
- Verify network connectivity: `ping <vm-ip>`

#### 3. Terraform State Issues

**Symptoms**: Terraform apply fails with state errors

**Solutions**:
- Check state directory permissions: `/var/lib/libvirt/terraform/k3s-production-cluster`
- Verify no concurrent runs (check concurrency group)
- Review Terraform logs in artifacts

#### 4. K3s API Not Ready

**Symptoms**: Cluster validation fails

**Solutions**:
- Check master node logs: `journalctl -u k3s`
- Verify API server health: `curl -k https://<master-ip>:6443/healthz`
- Check node status: `kubectl get nodes`
- Review comprehensive logs in artifacts

### Debugging Commands

```bash
# Check VM status
virsh list --all | grep k3s-production

# Check network
virsh net-list --all

# Check storage
virsh vol-list default | grep k3s-production

# SSH to VM
ssh -i /tmp/k3s-cluster-key ubuntu@<vm-ip>

# Check K3s status
kubectl get nodes -o wide
kubectl get pods -A
kubectl get events --sort-by='.lastTimestamp'
```

## 📊 Monitoring and Logs

### Artifacts

Each deployment generates comprehensive artifacts:

- **kubeconfig**: Cluster access configuration
- **health-report.md**: Cluster health summary
- **cluster-logs/**: Comprehensive log collection
  - `host-system.log`: Host system logs
  - `libvirt.log`: Libvirt daemon logs
  - `vm-*/`: Per-VM logs (system, K3s, network, disk, memory)
  - `cluster-info.log`: Kubernetes cluster info
  - `nodes.log`: Kubernetes nodes
  - `pods.log`: Kubernetes pods
  - `services.log`: Kubernetes services
  - `events.log`: Kubernetes events
  - `pod-logs/*.log`: Individual pod logs
  - `terraform.tfstate`: Terraform state
  - `terraform-plan.log`: Terraform plan output
  - `terraform-apply.log`: Terraform apply output

### Health Checks

The pipeline performs comprehensive health checks:

1. **Preflight**: Runner environment validation
2. **IP Collision**: Network address conflict detection
3. **VM Readiness**: Cloud-init and SSH connectivity
4. **K3s API**: Kubernetes API server health
5. **Cluster Validation**: Node and pod status verification

## 🧹 Cleanup

### Safe Cleanup

The cleanup workflow is designed to be safe and scoped:

```bash
# Trigger cleanup via GitHub Actions UI
# Requires confirmation: type "DESTROY"
gh workflow run cleanup-hardened.yml
```

**Safety Features**:
- Confirmation required (`DESTROY`)
- Scoped to `k3s-production` prefixed resources only
- Never touches default libvirt network/pool
- Preserves Terraform state by default
- Concurrency protection

### Manual Cleanup

If needed, manual cleanup commands:

```bash
# Stop and undefine VMs
for vm in $(virsh list --all --name | grep k3s-production); do
  virsh destroy $vm 2>/dev/null || true
  virsh undefine $vm --remove-all-storage 2>/dev/null || true
done

# Remove volumes
for vol in $(virsh vol-list default | grep k3s-production | awk '{print $1}'); do
  virsh vol-delete --pool default $vol 2>/dev/null || true
done

# Clean up cloud-init ISOs
rm -f /var/lib/libvirt/images/*cloudinit*.iso
```

## 🔄 Updates and Maintenance

### Automated Updates

- **Dependabot**: Weekly updates for GitHub Actions
- **Renovate**: Weekly updates for Terraform providers and Ansible
- **CI Validation**: All updates tested before merge

### Manual Updates

1. **K3s Version**: Update `K3S_VERSION` in workflow
2. **Terraform Version**: Update `TF_VERSION` in workflow
3. **Ansible Version**: Update `ANSIBLE_VERSION` in workflow
4. **Provider Versions**: Update `terraform/versions.tf`

## 📚 Additional Resources

- [K3s Documentation](https://docs.k3s.io/)
- [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest)
- [Ansible Documentation](https://docs.ansible.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review the comprehensive logs in artifacts
3. Check GitHub Actions logs
4. Create an issue with detailed information

---

**Note**: This hardened deployment pipeline is designed for production use with proper security, safety, and observability features. Always test in a non-production environment first.
