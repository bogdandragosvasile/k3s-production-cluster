# K3s Cluster Scaling Guide

This guide provides comprehensive instructions for scaling your K3s cluster up or down based on workload requirements.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Scaling Methods](#scaling-methods)
- [Scaling Presets](#scaling-presets)
- [Manual Scaling](#manual-scaling)
- [GitHub Actions Scaling](#github-actions-scaling)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The K3s cluster scaling system allows you to dynamically adjust the number of nodes based on your workload requirements:

- **Scale Up**: Add more nodes for increased capacity
- **Scale Down**: Remove nodes to reduce costs
- **Preset Configurations**: Use predefined configurations for common scenarios
- **Manual Control**: Fine-tune individual node counts
- **Automated Scaling**: Use GitHub Actions for automated scaling

## Quick Start

### 1. Check Current Status

```bash
# Show current cluster status
./scripts/quick-scale.sh status

# List available presets
./scripts/quick-scale.sh presets
```

### 2. Scale Using Presets

```bash
# Scale to minimal configuration (1 master, 1 worker)
./scripts/scaling-presets.sh minimal

# Scale to production configuration (3 masters, 6 workers, 2 storage, 2 LB)
./scripts/scaling-presets.sh production

# Scale to high-load configuration (5 masters, 12 workers, 3 storage, 2 LB)
./scripts/scaling-presets.sh high-load
```

### 3. Manual Scaling

```bash
# Scale up workers
./scripts/quick-scale.sh up --workers 5

# Scale down workers
./scripts/quick-scale.sh down --workers 2

# Scale with dry run (preview changes)
./scripts/quick-scale.sh up --workers 8 --dry-run
```

## Scaling Methods

### 1. Quick Scale Commands

The `quick-scale.sh` script provides simple commands for common scaling operations:

```bash
# Basic commands
./scripts/quick-scale.sh status          # Show current status
./scripts/quick-scale.sh presets         # List available presets
./scripts/quick-scale.sh up [options]    # Scale up
./scripts/quick-scale.sh down [options]  # Scale down
./scripts/quick-scale.sh help            # Show help

# Scale up examples
./scripts/quick-scale.sh up --workers 5
./scripts/quick-scale.sh up --masters 3 --workers 8
./scripts/quick-scale.sh up --storage 3 --gpu 2

# Scale down examples
./scripts/quick-scale.sh down --workers 2
./scripts/quick-scale.sh down --masters 1 --workers 3
```

### 2. Scaling Presets

The `scaling-presets.sh` script provides predefined configurations:

```bash
# Available presets
./scripts/scaling-presets.sh minimal        # 1 master, 1 worker
./scripts/scaling-presets.sh development    # 1 master, 2 workers, 1 storage
./scripts/scaling-presets.sh staging        # 3 masters, 3 workers, 2 storage, 2 LB
./scripts/scaling-presets.sh production     # 3 masters, 6 workers, 2 storage, 2 LB
./scripts/scaling-presets.sh high-load      # 5 masters, 12 workers, 3 storage, 2 LB
./scripts/scaling-presets.sh gpu-enabled    # 3 masters, 4 workers, 2 storage, 2 LB, 2 GPU
./scripts/scaling-presets.sh cost-optimized # 1 master, 3 workers, 1 storage
./scripts/scaling-presets.sh ha-minimal     # 3 masters, 2 workers, 2 storage, 2 LB

# List all presets with descriptions
./scripts/scaling-presets.sh list
```

### 3. Manual Scaling

The `scale-cluster.sh` script provides full control over scaling:

```bash
# Basic usage
./scripts/scale-cluster.sh [options]

# Examples
./scripts/scale-cluster.sh --masters 3 --workers 6 --storage 2
./scripts/scale-cluster.sh --environment production --workers 8
./scripts/scale-cluster.sh --dry-run --masters 1 --workers 2
```

## Scaling Presets

### Minimal (1 master, 1 worker)
- **Use case**: Local development, testing, CI/CD
- **Resources**: Minimal CPU and memory
- **Cost**: Lowest
- **Availability**: Single point of failure

### Development (1 master, 2 workers, 1 storage)
- **Use case**: Development environment, feature testing
- **Resources**: Basic storage for development
- **Cost**: Low
- **Availability**: Single master, basic redundancy

### Staging (3 masters, 3 workers, 2 storage, 2 LB)
- **Use case**: Pre-production testing, integration testing
- **Resources**: HA masters, load balancing
- **Cost**: Medium
- **Availability**: High availability

### Production (3 masters, 6 workers, 2 storage, 2 LB)
- **Use case**: Production workloads, customer-facing applications
- **Resources**: HA masters, load balancing, adequate capacity
- **Cost**: High
- **Availability**: High availability

### High Load (5 masters, 12 workers, 3 storage, 2 LB)
- **Use case**: High-traffic applications, data processing
- **Resources**: Multiple masters, high worker capacity
- **Cost**: Very high
- **Availability**: Very high availability

### GPU Enabled (3 masters, 4 workers, 2 storage, 2 LB, 2 GPU)
- **Use case**: Machine learning, AI workloads, GPU computing
- **Resources**: GPU nodes for compute-intensive tasks
- **Cost**: Very high
- **Availability**: High availability

### Cost Optimized (1 master, 3 workers, 1 storage)
- **Use case**: Budget-constrained environments, small teams
- **Resources**: Minimal HA, basic storage
- **Cost**: Low
- **Availability**: Basic redundancy

### HA Minimal (3 masters, 2 workers, 2 storage, 2 LB)
- **Use case**: Small HA deployments, critical applications
- **Resources**: HA masters, load balancing, minimal workers
- **Cost**: Medium
- **Availability**: High availability

## Manual Scaling

### Command Line Options

```bash
./scripts/scale-cluster.sh [OPTIONS]

Options:
  -e, --environment ENV    Environment (development, staging, production)
  -c, --cluster-name NAME  Cluster name
  -m, --masters COUNT      Number of master nodes
  -w, --workers COUNT      Number of worker nodes
  -s, --storage COUNT      Number of storage nodes
  -l, --loadbalancers COUNT Number of load balancer nodes
  -g, --gpu COUNT          Number of GPU nodes
  --dry-run                Show what would be changed without applying
  --force                  Force scaling even if cluster is not ready
  -h, --help               Show help message
```

### Examples

```bash
# Scale to specific configuration
./scripts/scale-cluster.sh \
  --environment production \
  --cluster-name k3s-prod \
  --masters 3 \
  --workers 8 \
  --storage 2 \
  --loadbalancers 2

# Preview changes before applying
./scripts/scale-cluster.sh \
  --masters 1 \
  --workers 2 \
  --dry-run

# Force scaling even if cluster is not ready
./scripts/scale-cluster.sh \
  --workers 5 \
  --force
```

## GitHub Actions Scaling

### Manual Scaling Workflow

1. Go to the **Actions** tab in your GitHub repository
2. Select **Scale K3s Cluster** workflow
3. Click **Run workflow**
4. Configure the scaling parameters:
   - **Environment**: development, staging, production
   - **Preset**: Choose from available presets
   - **Cluster name**: Name of your cluster
   - **Force**: Force scaling even if cluster is not ready
   - **Dry run**: Preview changes without applying

### Workflow Features

- **Automated scaling**: Apply presets or custom configurations
- **Dry run support**: Preview changes before applying
- **Health verification**: Verify cluster health after scaling
- **Artifact generation**: Generate scaling reports
- **Error handling**: Comprehensive error handling and rollback

## Best Practices

### 1. Scaling Up

- **Plan ahead**: Monitor resource usage and plan scaling before reaching limits
- **Gradual scaling**: Scale up gradually to avoid overwhelming the cluster
- **Test changes**: Use dry-run mode to preview changes
- **Monitor health**: Verify cluster health after scaling

### 2. Scaling Down

- **Drain nodes**: Ensure workloads are moved before removing nodes
- **Maintain HA**: Keep odd number of masters for HA
- **Monitor impact**: Watch for performance impact after scaling down
- **Backup state**: Ensure Terraform state is backed up

### 3. Environment-Specific Scaling

- **Development**: Use minimal or development presets
- **Staging**: Use staging preset for pre-production testing
- **Production**: Use production or high-load presets
- **Cost optimization**: Use cost-optimized preset for budget constraints

### 4. Monitoring and Alerting

- **Resource monitoring**: Monitor CPU, memory, and storage usage
- **Node health**: Monitor node status and readiness
- **Application performance**: Monitor application performance after scaling
- **Cost tracking**: Track costs associated with scaling

## Troubleshooting

### Common Issues

#### 1. Scaling Fails

**Problem**: Scaling operation fails with errors

**Solutions**:
- Check cluster health: `./scripts/quick-scale.sh status`
- Verify prerequisites: Ensure Terraform, Ansible, and kubectl are available
- Check permissions: Ensure proper permissions for libvirt operations
- Review logs: Check Terraform and Ansible logs for errors

#### 2. Nodes Not Ready

**Problem**: Nodes are created but not ready

**Solutions**:
- Wait for nodes: Nodes may take time to become ready
- Check SSH connectivity: Ensure SSH keys are properly configured
- Verify Ansible playbook: Check Ansible playbook execution
- Review node logs: Check node logs for errors

#### 3. State Conflicts

**Problem**: Terraform state conflicts during scaling

**Solutions**:
- Backup state: Always backup Terraform state before scaling
- Resolve conflicts: Use `terraform refresh` to sync state
- Manual intervention: Manually resolve state conflicts if needed
- Re-initialize: Re-initialize Terraform if necessary

#### 4. Resource Constraints

**Problem**: Insufficient resources for scaling

**Solutions**:
- Check available resources: Verify CPU, memory, and storage availability
- Scale down first: Remove unnecessary nodes before scaling up
- Optimize configuration: Use smaller node sizes if needed
- Add resources: Add more physical resources to the host

### Debugging Commands

```bash
# Check current cluster status
./scripts/quick-scale.sh status

# Check Terraform state
cd terraform && terraform show

# Check Kubernetes cluster
KUBECONFIG="./kubeconfig" kubectl get nodes
KUBECONFIG="./kubeconfig" kubectl get pods -A

# Check libvirt resources
virsh list --all
virsh pool-list
virsh net-list

# Check system resources
free -h
df -h
```

### Getting Help

1. **Check logs**: Review Terraform and Ansible logs
2. **Verify configuration**: Ensure all configuration files are correct
3. **Test connectivity**: Verify SSH and Kubernetes connectivity
4. **Review documentation**: Check this guide and other documentation
5. **Community support**: Seek help from the community if needed

## Conclusion

The K3s cluster scaling system provides flexible and powerful tools for managing your cluster size based on workload requirements. Whether you need to scale up for high load or scale down for cost optimization, the system provides multiple approaches to meet your needs.

Remember to:
- Plan scaling operations carefully
- Test changes in non-production environments first
- Monitor cluster health after scaling
- Keep backups of your Terraform state
- Follow best practices for your specific use case

For more information, refer to the other documentation files in this repository.
