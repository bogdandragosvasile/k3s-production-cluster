# K3s Production Cluster - Operator Runbook

This runbook provides operational procedures for managing the hardened K3s production cluster deployment.

## Table of Contents

- [Overview](#overview)
- [Emergency Procedures](#emergency-procedures)
- [Routine Operations](#routine-operations)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Security Operations](#security-operations)
- [Backup and Recovery](#backup-and-recovery)
- [Scaling Operations](#scaling-operations)
- [Disaster Recovery](#disaster-recovery)

## Overview

This runbook covers operational procedures for the K3s production cluster with hardened security features, multi-environment support, and comprehensive monitoring.

### Key Components

- **Control Plane**: K3s master nodes with high availability
- **Worker Nodes**: K3s agent nodes for workload execution
- **Storage**: Longhorn distributed storage system
- **Load Balancing**: MetalLB for service load balancing
- **Monitoring**: Prometheus, Grafana, and health reporting
- **Security**: SOPS/age encryption, RBAC, and network policies

### Environment Structure

- **Production**: `k3s-production-*` resources
- **Staging**: `k3s-staging-*` resources  
- **Development**: `k3s-dev-*` resources

## Emergency Procedures

### 1. Cluster Down - Immediate Response

**Symptoms**: Cannot connect to cluster, kubectl commands fail

**Immediate Actions**:
```bash
# 1. Check VM status
virsh list --all | grep k3s

# 2. Check master node
virsh console k3s-production-master

# 3. Check K3s service
sudo systemctl status k3s

# 4. Check logs
sudo journalctl -u k3s -f
```

**Recovery Steps**:
```bash
# 1. Restart K3s service
sudo systemctl restart k3s

# 2. Wait for cluster to stabilize
sleep 60

# 3. Verify cluster health
kubectl get nodes
kubectl get pods -A
```

### 2. Master Node Failure

**Symptoms**: Master node unreachable, cluster API unavailable

**Immediate Actions**:
```bash
# 1. Check VM status
virsh list --all | grep master

# 2. Check VM console
virsh console k3s-production-master

# 3. Check system resources
free -h
df -h
```

**Recovery Steps**:
```bash
# 1. Restart VM if needed
virsh start k3s-production-master

# 2. Wait for VM to boot
sleep 120

# 3. Check K3s service
sudo systemctl status k3s

# 4. Restart K3s if needed
sudo systemctl restart k3s
```

### 3. Worker Node Failure

**Symptoms**: Worker node unreachable, pods not scheduling

**Immediate Actions**:
```bash
# 1. Check VM status
virsh list --all | grep worker

# 2. Check VM console
virsh console k3s-production-worker-1

# 3. Check system resources
free -h
df -h
```

**Recovery Steps**:
```bash
# 1. Restart VM if needed
virsh start k3s-production-worker-1

# 2. Wait for VM to boot
sleep 120

# 3. Check K3s agent service
sudo systemctl status k3s-agent

# 4. Restart K3s agent if needed
sudo systemctl restart k3s-agent
```

### 4. Storage Issues

**Symptoms**: PVCs stuck in Pending, storage errors

**Immediate Actions**:
```bash
# 1. Check Longhorn status
kubectl get pods -n longhorn-system

# 2. Check storage classes
kubectl get storageclass

# 3. Check PVs and PVCs
kubectl get pv,pvc -A
```

**Recovery Steps**:
```bash
# 1. Restart Longhorn pods
kubectl rollout restart deployment -n longhorn-system

# 2. Check Longhorn logs
kubectl logs -n longhorn-system -l app=longhorn-manager

# 3. Verify storage functionality
kubectl run test-pod --image=busybox --rm -it --restart=Never -- /bin/sh
```

## Routine Operations

### 1. Daily Health Checks

**Morning Routine** (5 minutes):
```bash
# 1. Check cluster health
kubectl get nodes
kubectl get pods -A | grep -v Running

# 2. Check resource usage
kubectl top nodes
kubectl top pods -A

# 3. Check recent events
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

**Evening Routine** (10 minutes):
```bash
# 1. Generate health report
./scripts/generate-health-report.sh <master-ip> <kubeconfig-path>

# 2. Check storage usage
kubectl get pv,pvc -A
df -h

# 3. Review logs for errors
kubectl logs -n kube-system -l app=longhorn-manager --since=24h
```

### 2. Weekly Maintenance

**System Updates**:
```bash
# 1. Update system packages
sudo apt update && sudo apt upgrade -y

# 2. Update K3s (if needed)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 sh -

# 3. Restart services
sudo systemctl restart k3s
```

**Storage Maintenance**:
```bash
# 1. Check Longhorn health
kubectl get pods -n longhorn-system

# 2. Clean up old snapshots
kubectl get volumesnapshot -A

# 3. Check storage capacity
kubectl get pv,pvc -A
```

### 3. Monthly Operations

**Security Updates**:
```bash
# 1. Update SOPS/age keys
sops --rotate-age-key terraform/terraform.tfvars

# 2. Rotate certificates
kubectl get certificates -A

# 3. Review RBAC
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A
```

**Backup Verification**:
```bash
# 1. Test backup restoration
kubectl get pv,pvc -A > backup-test-$(date +%Y%m%d).txt

# 2. Verify state backups
ls -la /var/lib/libvirt/terraform/

# 3. Test disaster recovery procedures
```

## Monitoring and Alerting

### 1. Key Metrics to Monitor

**Cluster Health**:
- Node status (Ready/NotReady)
- Pod status (Running/Pending/Failed)
- API server availability
- etcd health

**Resource Usage**:
- CPU utilization per node
- Memory utilization per node
- Storage usage per node
- Network I/O per node

**Application Health**:
- Pod restart counts
- Container crash loops
- Service availability
- Ingress functionality

### 2. Alerting Thresholds

**Critical Alerts**:
- Any node down for > 5 minutes
- API server unavailable for > 2 minutes
- Storage system down for > 10 minutes
- Pod crash loops > 5 restarts in 10 minutes

**Warning Alerts**:
- CPU usage > 80% for > 10 minutes
- Memory usage > 85% for > 10 minutes
- Storage usage > 90%
- Pod pending for > 5 minutes

### 3. Monitoring Commands

**Real-time Monitoring**:
```bash
# Watch node status
watch kubectl get nodes

# Watch pod status
watch kubectl get pods -A

# Monitor resource usage
watch kubectl top nodes
```

**Log Monitoring**:
```bash
# Follow K3s logs
sudo journalctl -u k3s -f

# Follow application logs
kubectl logs -f <pod-name> -n <namespace>

# Follow all logs
kubectl logs -f -l app=<app-label> -n <namespace>
```

## Troubleshooting

### 1. Common Issues

**Pod Stuck in Pending**:
```bash
# Check pod description
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace>

# Check resource constraints
kubectl describe node <node-name>
```

**Service Not Accessible**:
```bash
# Check service status
kubectl get svc -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Check ingress
kubectl get ingress -n <namespace>
```

**Storage Issues**:
```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# Check PV status
kubectl describe pv <pv-name>

# Check storage class
kubectl describe storageclass <storage-class-name>
```

### 2. Debug Commands

**Cluster Information**:
```bash
# Cluster version
kubectl version

# Cluster info
kubectl cluster-info

# API resources
kubectl api-resources
```

**Node Information**:
```bash
# Node details
kubectl describe node <node-name>

# Node resources
kubectl top node <node-name>

# Node conditions
kubectl get node <node-name> -o yaml
```

**Pod Information**:
```bash
# Pod details
kubectl describe pod <pod-name> -n <namespace>

# Pod logs
kubectl logs <pod-name> -n <namespace>

# Pod exec
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
```

### 3. Log Analysis

**System Logs**:
```bash
# K3s logs
sudo journalctl -u k3s --since=1h

# K3s agent logs
sudo journalctl -u k3s-agent --since=1h

# System logs
sudo journalctl --since=1h
```

**Application Logs**:
```bash
# All pods in namespace
kubectl logs -l app=<app-label> -n <namespace>

# Previous container logs
kubectl logs <pod-name> -n <namespace> --previous

# Logs with timestamps
kubectl logs <pod-name> -n <namespace> --timestamps
```

## Maintenance

### 1. Regular Maintenance Tasks

**Daily**:
- Check cluster health
- Monitor resource usage
- Review error logs

**Weekly**:
- Update system packages
- Clean up old logs
- Verify backups

**Monthly**:
- Security updates
- Certificate rotation
- Performance review

### 2. Maintenance Procedures

**System Updates**:
```bash
# 1. Check for updates
sudo apt update

# 2. Review available updates
sudo apt list --upgradable

# 3. Apply updates
sudo apt upgrade -y

# 4. Restart services
sudo systemctl restart k3s
```

**Certificate Management**:
```bash
# 1. Check certificate expiration
kubectl get certificates -A

# 2. Renew certificates
kubectl delete certificate <cert-name> -n <namespace>

# 3. Verify new certificates
kubectl get certificates -A
```

**Log Rotation**:
```bash
# 1. Check log sizes
sudo du -sh /var/log/*

# 2. Rotate logs
sudo logrotate -f /etc/logrotate.conf

# 3. Clean old logs
sudo find /var/log -name "*.log.*" -mtime +30 -delete
```

### 3. Performance Optimization

**Resource Tuning**:
```bash
# 1. Check resource limits
kubectl describe node <node-name>

# 2. Adjust resource requests
kubectl edit deployment <deployment-name> -n <namespace>

# 3. Monitor performance
kubectl top nodes
kubectl top pods -A
```

**Storage Optimization**:
```bash
# 1. Check storage usage
kubectl get pv,pvc -A

# 2. Clean up old volumes
kubectl delete pv <old-pv-name>

# 3. Optimize storage classes
kubectl edit storageclass <storage-class-name>
```

## Security Operations

### 1. Security Monitoring

**Access Monitoring**:
```bash
# Check RBAC
kubectl get roles,rolebindings,clusterroles,clusterrolebindings -A

# Check service accounts
kubectl get serviceaccounts -A

# Check security contexts
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}'
```

**Network Security**:
```bash
# Check network policies
kubectl get networkpolicies -A

# Check ingress
kubectl get ingress -A

# Check services
kubectl get svc -A
```

### 2. Security Updates

**SOPS Key Rotation**:
```bash
# 1. Generate new age key
age-keygen -o age-key.txt

# 2. Update SOPS configuration
sops --rotate-age-key terraform/terraform.tfvars

# 3. Update GitHub secrets
gh secret set SOPS_AGE_KEY < age-key.txt
```

**Certificate Rotation**:
```bash
# 1. Check certificate expiration
kubectl get certificates -A

# 2. Force certificate renewal
kubectl delete certificate <cert-name> -n <namespace>

# 3. Verify new certificates
kubectl get certificates -A
```

### 3. Security Auditing

**Regular Audits**:
```bash
# 1. Check for privileged pods
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.securityContext.privileged}{"\n"}{end}' | grep true

# 2. Check for host network pods
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.hostNetwork}{"\n"}{end}' | grep true

# 3. Check for host PID pods
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.hostPID}{"\n"}{end}' | grep true
```

## Backup and Recovery

### 1. Backup Procedures

**State Backup**:
```bash
# 1. Backup Terraform state
cp /var/lib/libvirt/terraform/k3s-production-* /backup/terraform/

# 2. Backup kubeconfig
cp ~/.kube/config /backup/kubeconfig/

# 3. Backup SOPS keys
cp age-key.txt /backup/keys/
```

**Application Backup**:
```bash
# 1. Backup PVCs
kubectl get pvc -A -o yaml > /backup/pvc-backup-$(date +%Y%m%d).yaml

# 2. Backup configurations
kubectl get configmaps,secrets -A -o yaml > /backup/config-backup-$(date +%Y%m%d).yaml

# 3. Backup deployments
kubectl get deployments,services,ingress -A -o yaml > /backup/app-backup-$(date +%Y%m%d).yaml
```

### 2. Recovery Procedures

**State Recovery**:
```bash
# 1. Restore Terraform state
cp /backup/terraform/k3s-production-* /var/lib/libvirt/terraform/

# 2. Restore kubeconfig
cp /backup/kubeconfig/config ~/.kube/config

# 3. Restore SOPS keys
cp /backup/keys/age-key.txt .
```

**Application Recovery**:
```bash
# 1. Restore PVCs
kubectl apply -f /backup/pvc-backup-$(date +%Y%m%d).yaml

# 2. Restore configurations
kubectl apply -f /backup/config-backup-$(date +%Y%m%d).yaml

# 3. Restore deployments
kubectl apply -f /backup/app-backup-$(date +%Y%m%d).yaml
```

### 3. Disaster Recovery

**Complete Cluster Recovery**:
```bash
# 1. Recreate infrastructure
cd terraform
terraform apply

# 2. Deploy K3s cluster
cd ../ansible
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml

# 3. Restore applications
kubectl apply -f /backup/app-backup-$(date +%Y%m%d).yaml
```

## Scaling Operations

### 1. Horizontal Scaling

**Add Worker Nodes**:
```bash
# 1. Update Terraform configuration
# Add new worker nodes to terraform/main.tf

# 2. Apply infrastructure changes
terraform apply

# 3. Deploy K3s agent
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml --limit=worker
```

**Remove Worker Nodes**:
```bash
# 1. Drain node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 2. Remove from cluster
kubectl delete node <node-name>

# 3. Update Terraform configuration
# Remove worker nodes from terraform/main.tf
terraform apply
```

### 2. Vertical Scaling

**Increase Node Resources**:
```bash
# 1. Update VM configuration
virsh edit k3s-production-worker-1

# 2. Increase memory/CPU
# Update memory and vcpu settings

# 3. Restart VM
virsh reboot k3s-production-worker-1
```

### 3. Storage Scaling

**Add Storage Nodes**:
```bash
# 1. Update Terraform configuration
# Add new storage nodes to terraform/main.tf

# 2. Apply infrastructure changes
terraform apply

# 3. Deploy Longhorn
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
```

## Disaster Recovery

### 1. Recovery Planning

**Recovery Time Objectives (RTO)**:
- Critical services: 4 hours
- Non-critical services: 24 hours
- Complete cluster: 48 hours

**Recovery Point Objectives (RPO)**:
- State data: 1 hour
- Application data: 4 hours
- Configuration data: 1 hour

### 2. Recovery Procedures

**Partial Failure Recovery**:
```bash
# 1. Identify failed components
kubectl get nodes
kubectl get pods -A

# 2. Restart failed services
sudo systemctl restart k3s

# 3. Verify recovery
kubectl get nodes
kubectl get pods -A
```

**Complete Failure Recovery**:
```bash
# 1. Recreate infrastructure
terraform apply

# 2. Deploy K3s cluster
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml

# 3. Restore applications
kubectl apply -f /backup/app-backup-$(date +%Y%m%d).yaml
```

### 3. Testing Recovery

**Regular Testing**:
```bash
# 1. Test backup restoration
kubectl apply -f /backup/app-backup-$(date +%Y%m%d).yaml

# 2. Test disaster recovery
terraform destroy
terraform apply

# 3. Verify functionality
kubectl get nodes
kubectl get pods -A
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

### Escalation Procedures

1. **Level 1**: Primary on-call engineer
2. **Level 2**: Secondary on-call engineer
3. **Level 3**: Team lead or manager
4. **Level 4**: External support or vendor

---

*This runbook is part of the K3s Production Cluster project. For questions or issues, please refer to the project documentation or open an issue.*
