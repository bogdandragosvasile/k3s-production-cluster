# K3s Production Cluster - Hardened Deployment Guide

This guide provides comprehensive instructions for deploying a hardened K3s production cluster using the enhanced GitHub Actions workflows and security features.

## Overview

The hardened K3s production cluster deployment includes:

- **Multi-environment support** (production, staging, development)
- **Comprehensive security scanning** and static analysis
- **Automated artifact collection** and health reporting
- **Secret management** with SOPS/age encryption
- **Robust readiness gates** with clear retries and timeouts
- **Parallel deployment** with environment-specific concurrency groups
- **Comprehensive cleanup** with resource preservation options

## Prerequisites

### System Requirements

- **Host OS**: Ubuntu 24.04 LTS (recommended)
- **Memory**: 8GB+ RAM
- **Storage**: 50GB+ available disk space
- **CPU**: 4+ cores
- **Network**: Internet connectivity for package downloads

### Software Requirements

- **Libvirt**: Virtualization support
- **KVM**: Hardware virtualization
- **Terraform**: 1.6.0+
- **Ansible**: 2.15.0+
- **Git**: Version control
- **SSH**: Key-based authentication

### GitHub Requirements

- **GitHub Actions**: Enabled for the repository
- **Self-hosted runners**: Configured with libvirt support
- **Secrets**: SSH keys and other sensitive data
- **Permissions**: Workflow execution permissions

## Security Features

### Static Analysis Integration

- **Pre-commit hooks**: Automated code quality checks
- **Terraform security**: TFLint and TFSec analysis
- **Ansible security**: ansible-lint and security checks
- **Shell security**: ShellCheck analysis
- **Secret detection**: Comprehensive credential scanning
- **CodeQL**: GitHub's semantic code analysis

### Secret Management

- **SOPS/age encryption**: Secure variable management
- **Environment isolation**: Separate keys per environment
- **Team collaboration**: Multi-recipient encryption
- **CI/CD integration**: Secure secret handling

### Deployment Security

- **Ephemeral SSH keys**: Temporary key usage
- **Resource isolation**: Environment-specific prefixes
- **State protection**: Secure Terraform state management
- **Artifact sanitization**: Safe sharing of sensitive data

## Deployment Options

### 1. Automated Deployment (Recommended)

Deploy using GitHub Actions workflows:

```bash
# Trigger deployment via GitHub CLI
gh workflow run deploy-hardened.yml \
  --ref main \
  -f environments="production" \
  -f cluster_name="k3s" \
  -f force_cleanup="false"

# Or via GitHub UI
# Go to Actions → Deploy K3s Production Cluster (Hardened) → Run workflow
```

### 2. Manual Deployment

Deploy manually using scripts:

```bash
# 1. Run preflight checks
./scripts/preflight-checks.sh

# 2. Generate backend configuration
./scripts/generate-backend.sh

# 3. Deploy infrastructure
cd terraform
terraform init
terraform plan
terraform apply

# 4. Deploy K3s cluster
cd ../ansible
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml
```

### 3. Environment-Specific Deployment

Deploy to specific environments:

```bash
# Production only
gh workflow run deploy-hardened.yml -f environments="production"

# Staging and development
gh workflow run deploy-hardened.yml -f environments="staging,development"

# All environments
gh workflow run deploy-hardened.yml -f environments="production,staging,development"
```

## Configuration

### Environment Variables

Set the following environment variables:

```bash
export ENVIRONMENT="production"           # Environment name
export CLUSTER_NAME="k3s"               # Cluster name
export RESOURCE_PREFIX="k3s-production-k3s"  # Resource prefix
export TF_VERSION="1.6.0"               # Terraform version
export ANSIBLE_VERSION="2.15.0"         # Ansible version
export K3S_VERSION="v1.33.4+k3s1"       # K3s version
```

### Terraform Configuration

Configure Terraform variables:

```bash
# Copy example configuration
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit with your values
vim terraform/terraform.tfvars

# Encrypt sensitive values with SOPS
sops terraform/terraform.tfvars
```

### Ansible Configuration

Configure Ansible inventory:

```bash
# Inventory is generated automatically by Terraform
# Manual configuration available in ansible/inventory.yml
```

### GitHub Secrets

Configure the following secrets in GitHub:

- `SSH_PRIVATE_KEY`: Private SSH key for VM access
- `SSH_PUBLIC_KEY`: Public SSH key for VM access
- `SOPS_AGE_KEY`: Age private key for secret decryption

## Deployment Process

### 1. Pre-deployment Checks

The deployment process includes comprehensive pre-deployment checks:

- **Static analysis**: Code quality and security scanning
- **Preflight checks**: System requirements validation
- **Resource validation**: IP collision detection
- **Security scanning**: Secret detection and vulnerability analysis

### 2. Infrastructure Deployment

Terraform creates the infrastructure:

- **Virtual machines**: Master, worker, storage, and load balancer nodes
- **Networking**: Libvirt network configuration
- **Storage**: VM disk images and volumes
- **Security**: SSH key configuration

### 3. Cluster Deployment

Ansible deploys the K3s cluster:

- **Bootstrap**: VM preparation and package installation
- **Control plane**: K3s master node deployment
- **Workers**: K3s agent node deployment
- **Storage**: Longhorn storage deployment
- **Load balancing**: MetalLB load balancer deployment

### 4. Validation and Health Checks

Comprehensive validation includes:

- **Cluster health**: Node and pod status verification
- **Service validation**: API server and service availability
- **Storage validation**: Persistent volume functionality
- **Network validation**: Load balancer and ingress functionality

### 5. Artifact Collection

Automated artifact collection:

- **Cluster information**: Nodes, pods, services, events
- **Logs**: System, K3s, and application logs
- **Configuration**: Kubeconfig and configuration files
- **Metrics**: Resource usage and performance data

## Post-Deployment

### 1. Access the Cluster

Download the sanitized kubeconfig:

```bash
# Download from GitHub Actions artifacts
gh run download <run-id> --name kubeconfig-sanitized

# Or download from the Actions UI
# Go to Actions → Select run → Download kubeconfig-sanitized artifact
```

### 2. Configure Local Access

Set up local kubectl access:

```bash
# Replace placeholders in sanitized kubeconfig
sed -i 's/MASTER_IP/192.168.122.10/g' kubeconfig-sanitized

# Set kubeconfig
export KUBECONFIG=./kubeconfig-sanitized

# Test access
kubectl get nodes
kubectl get pods -A
```

### 3. Verify Deployment

Check cluster health:

```bash
# Check node status
kubectl get nodes -o wide

# Check pod status
kubectl get pods -A

# Check services
kubectl get svc -A

# Check storage
kubectl get pv,pvc -A
kubectl get storageclass
```

### 4. Review Health Report

Download and review the health report:

```bash
# Download health report
gh run download <run-id> --name health-report

# View health report
cat k3s-health-report.md
```

## Monitoring and Maintenance

### 1. Health Monitoring

Regular health checks:

```bash
# Generate health report
./scripts/generate-health-report.sh <master-ip> <kubeconfig-path>

# Check cluster status
kubectl cluster-info
kubectl get events -A --sort-by='.lastTimestamp'
```

### 2. Log Collection

Collect comprehensive logs:

```bash
# Collect all artifacts
./scripts/collect-artifacts.sh <master-ip> <kubeconfig-path>

# View specific logs
kubectl logs -n kube-system <pod-name>
```

### 3. Security Monitoring

Monitor security posture:

```bash
# Check for security issues
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}'

# Check RBAC
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A
```

### 4. Resource Management

Monitor resource usage:

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -A

# Check storage usage
kubectl get pv,pvc -A
df -h
```

## Troubleshooting

### Common Issues

#### 1. Deployment Failures

**Issue**: Workflow fails during deployment

**Solutions**:
- Check preflight checks output
- Review Terraform logs
- Verify Ansible inventory
- Check VM console logs

**Commands**:
```bash
# Check VM status
virsh list --all

# Check VM console
virsh console <vm-name>

# Check logs
kubectl logs -n kube-system <pod-name>
```

#### 2. Cluster Connectivity Issues

**Issue**: Cannot connect to cluster

**Solutions**:
- Verify kubeconfig configuration
- Check network connectivity
- Verify API server status
- Check firewall rules

**Commands**:
```bash
# Test connectivity
kubectl cluster-info

# Check API server
curl -k https://<master-ip>:6443/healthz

# Check network
ping <master-ip>
telnet <master-ip> 6443
```

#### 3. Pod Startup Issues

**Issue**: Pods not starting or crashing

**Solutions**:
- Check pod logs
- Verify resource constraints
- Check image availability
- Verify storage configuration

**Commands**:
```bash
# Check pod status
kubectl get pods -A

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check pod description
kubectl describe pod <pod-name> -n <namespace>
```

#### 4. Storage Issues

**Issue**: Persistent volumes not working

**Solutions**:
- Check Longhorn status
- Verify storage class configuration
- Check node storage capacity
- Verify PVC configuration

**Commands**:
```bash
# Check storage classes
kubectl get storageclass

# Check PVs and PVCs
kubectl get pv,pvc -A

# Check Longhorn status
kubectl get pods -n longhorn-system
```

### Debug Commands

Useful debugging commands:

```bash
# Cluster information
kubectl cluster-info
kubectl version

# Node information
kubectl get nodes -o wide
kubectl describe node <node-name>

# Pod information
kubectl get pods -A -o wide
kubectl describe pod <pod-name> -n <namespace>

# Service information
kubectl get svc -A
kubectl describe svc <service-name> -n <namespace>

# Events
kubectl get events -A --sort-by='.lastTimestamp'

# Logs
kubectl logs <pod-name> -n <namespace> --previous
kubectl logs <pod-name> -n <namespace> --tail=100
```

## Security Considerations

### 1. Access Control

- **RBAC**: Configure proper role-based access control
- **Service accounts**: Use dedicated service accounts
- **Network policies**: Implement network segmentation
- **Pod security**: Use security contexts and policies

### 2. Secret Management

- **SOPS encryption**: Use for sensitive configuration
- **Secret rotation**: Regularly rotate certificates and tokens
- **Access logging**: Monitor secret access
- **Backup security**: Secure backup of encrypted secrets

### 3. Network Security

- **Firewall rules**: Configure appropriate firewall rules
- **Network segmentation**: Isolate cluster traffic
- **TLS encryption**: Use TLS for all communications
- **Ingress security**: Secure ingress controllers

### 4. Monitoring and Auditing

- **Log aggregation**: Centralize log collection
- **Security monitoring**: Monitor for security events
- **Audit logging**: Enable Kubernetes audit logging
- **Compliance**: Regular security assessments

## Cleanup

### 1. Automated Cleanup

Use the cleanup workflow:

```bash
# Cleanup specific environments
gh workflow run cleanup-hardened.yml \
  -f environments="production" \
  -f cluster_name="k3s" \
  -f force_cleanup="false" \
  -f preserve_state="true"

# Cleanup all environments
gh workflow run cleanup-hardened.yml \
  -f environments="production,staging,development" \
  -f force_cleanup="true" \
  -f preserve_state="false"
```

### 2. Manual Cleanup

Clean up manually:

```bash
# Stop and remove VMs
virsh list --all --name | grep k3s | xargs -I {} virsh destroy {}
virsh list --all --name | grep k3s | xargs -I {} virsh undefine {} --remove-all-storage

# Remove volumes
virsh vol-list --pool default | grep k3s | awk '{print $1}' | xargs -I {} virsh vol-delete --pool default {}

# Remove state files
rm -rf /var/lib/libvirt/terraform/k3s-*
```

## Support and Resources

### Documentation

- [Static Checks Integration](STATIC-CHECKS-INTEGRATION.md)
- [SOPS/age Guide](SOPS-AGE-GUIDE.md)
- [Multi-Environment Guide](MULTI-ENVIRONMENT.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

### Tools

- **Pre-commit**: Local code quality checks
- **Terraform**: Infrastructure as code
- **Ansible**: Configuration management
- **Kubectl**: Kubernetes cluster management

### Community

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share experiences
- **Pull Requests**: Contribute improvements

---

*This guide is part of the K3s Production Cluster project. For questions or issues, please refer to the project documentation or open an issue.*
