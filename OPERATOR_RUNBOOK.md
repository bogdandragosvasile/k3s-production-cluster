# 🚀 K3s Production Cluster - Operator Runbook

## Quick Start Commands

### 1. Deploy Cluster
```bash
# Automated deployment (recommended)
gh workflow run deploy-hardened.yml \
  --ref main \
  -f environments="production" \
  -f cluster_name="k3s" \
  -f force_cleanup="false"

# Manual deployment
./scripts/preflight-checks.sh
./scripts/generate-backend.sh
cd terraform && terraform apply
cd ../ansible && ansible-playbook -i inventory.yml playbooks/install-k3s.yaml
```

### 2. Access Cluster
```bash
# Download kubeconfig from GitHub Actions artifacts
gh run download <run-id> --name kubeconfig-sanitized

# Replace placeholders and set kubeconfig
sed -i 's/MASTER_IP/192.168.122.10/g' kubeconfig-sanitized
export KUBECONFIG=./kubeconfig-sanitized

# Test access
kubectl get nodes
kubectl get pods -A
```

### 3. Health Checks
```bash
# Generate health report
./scripts/generate-health-report.sh <master-ip> <kubeconfig-path>

# Check cluster status
kubectl get nodes -o wide
kubectl get pods -A
kubectl get svc -A
```

## Emergency Procedures

### Cluster Down
```bash
# 1. Check VM status
virsh list --all | grep k3s

# 2. Check master node
virsh console k3s-production-master

# 3. Restart K3s service
sudo systemctl restart k3s

# 4. Verify recovery
kubectl get nodes
kubectl get pods -A
```

### Node Failure
```bash
# 1. Check VM status
virsh list --all | grep <node-name>

# 2. Restart VM
virsh start <node-name>

# 3. Check K3s service
sudo systemctl status k3s-agent

# 4. Restart service if needed
sudo systemctl restart k3s-agent
```

### Storage Issues
```bash
# 1. Check Longhorn status
kubectl get pods -n longhorn-system

# 2. Restart Longhorn
kubectl rollout restart deployment -n longhorn-system

# 3. Check storage classes
kubectl get storageclass
kubectl get pv,pvc -A
```

## Routine Operations

### Daily Checks
```bash
# Morning routine (5 minutes)
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
kubectl get events -A --sort-by='.lastTimestamp' | tail -20

# Evening routine (10 minutes)
./scripts/generate-health-report.sh <master-ip> <kubeconfig-path>
kubectl get pv,pvc -A
df -h
```

### Weekly Maintenance
```bash
# System updates
sudo apt update && sudo apt upgrade -y

# K3s update (if needed)
curl -sfL https://get.k3s.io | INSTALL_K3s_VERSION=v1.33.4+k3s1 sh -

# Restart services
sudo systemctl restart k3s
```

### Monthly Operations
```bash
# Security updates
sops --rotate-age-key terraform/terraform.tfvars

# Certificate rotation
kubectl get certificates -A

# Backup verification
kubectl get pv,pvc -A > backup-test-$(date +%Y%m%d).txt
```

## Troubleshooting

### Common Issues

#### Pod Stuck in Pending
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace>
kubectl describe node <node-name>
```

#### Service Not Accessible
```bash
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
kubectl get ingress -n <namespace>
```

#### Storage Issues
```bash
kubectl describe pvc <pvc-name> -n <namespace>
kubectl describe pv <pv-name>
kubectl describe storageclass <storage-class-name>
```

### Debug Commands
```bash
# Cluster info
kubectl cluster-info
kubectl version

# Node info
kubectl describe node <node-name>
kubectl top node <node-name>

# Pod info
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

## Monitoring

### Key Metrics
```bash
# Resource usage
kubectl top nodes
kubectl top pods -A

# Storage usage
kubectl get pv,pvc -A
df -h

# Events
kubectl get events -A --sort-by='.lastTimestamp'
```

### Log Monitoring
```bash
# K3s logs
sudo journalctl -u k3s -f

# Application logs
kubectl logs -f <pod-name> -n <namespace>

# All logs
kubectl logs -f -l app=<app-label> -n <namespace>
```

## Security

### Access Control
```bash
# Check RBAC
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A

# Check service accounts
kubectl get serviceaccounts -A

# Check security contexts
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}'
```

### Secret Management
```bash
# SOPS key rotation
age-keygen -o age-key.txt
sops --rotate-age-key terraform/terraform.tfvars
gh secret set SOPS_AGE_KEY < age-key.txt

# Certificate rotation
kubectl get certificates -A
kubectl delete certificate <cert-name> -n <namespace>
```

## Backup and Recovery

### Backup
```bash
# State backup
cp /var/lib/libvirt/terraform/k3s-production-* /backup/terraform/
cp ~/.kube/config /backup/kubeconfig/
cp age-key.txt /backup/keys/

# Application backup
kubectl get pvc -A -o yaml > /backup/pvc-backup-$(date +%Y%m%d).yaml
kubectl get configmaps,secrets -A -o yaml > /backup/config-backup-$(date +%Y%m%d).yaml
kubectl get deployments,services,ingress -A -o yaml > /backup/app-backup-$(date +%Y%m%d).yaml
```

### Recovery
```bash
# State recovery
cp /backup/terraform/k3s-production-* /var/lib/libvirt/terraform/
cp /backup/kubeconfig/config ~/.kube/config
cp /backup/keys/age-key.txt .

# Application recovery
kubectl apply -f /backup/pvc-backup-$(date +%Y%m%d).yaml
kubectl apply -f /backup/config-backup-$(date +%Y%m%d).yaml
kubectl apply -f /backup/app-backup-$(date +%Y%m%d).yaml
```

## Scaling

### Add Worker Nodes
```bash
# 1. Update Terraform configuration
# Add new worker nodes to terraform/main.tf

# 2. Apply infrastructure changes
terraform apply

# 3. Deploy K3s agent
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml --limit=worker
```

### Remove Worker Nodes
```bash
# 1. Drain node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 2. Remove from cluster
kubectl delete node <node-name>

# 3. Update Terraform configuration
# Remove worker nodes from terraform/main.tf
terraform apply
```

## Cleanup

### Automated Cleanup
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

### Manual Cleanup
```bash
# Stop and remove VMs
virsh list --all --name | grep k3s | xargs -I {} virsh destroy {}
virsh list --all --name | grep k3s | xargs -I {} virsh undefine {} --remove-all-storage

# Remove volumes
virsh vol-list --pool default | grep k3s | awk '{print $1}' | xargs -I {} virsh vol-delete --pool default {}

# Remove state files
rm -rf /var/lib/libvirt/terraform/k3s-*
```

## Contact Information

### Emergency Contacts
- **Primary On-Call**: [Contact Information]
- **Secondary On-Call**: [Contact Information]
- **Escalation**: [Contact Information]

### Resources
- **Documentation**: [Documentation URL]
- **Monitoring**: [Monitoring URL]
- **Tickets**: [Ticketing System URL]

---

*This runbook is part of the K3s Production Cluster project. For detailed procedures, see the full documentation in `docs/OPERATOR-RUNBOOK.md`.*
