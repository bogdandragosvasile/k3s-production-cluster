# K3s Production Cluster - Troubleshooting Guide

This guide helps diagnose and resolve common issues with the hardened K3s deployment pipeline.

## 🔍 Diagnostic Tools

### Preflight Checks

Run preflight checks manually:

```bash
./scripts/preflight-checks.sh
```

**Expected Output**:
- ✅ All required tools present
- ✅ Sudo access for libvirt
- ✅ Libvirt daemon running
- ✅ Default network/pool active
- ✅ SSH key available

### IP Collision Detection

Check for IP conflicts:

```bash
./scripts/check-ip-collisions.sh
```

**Expected Output**:
- ✅ No IP collisions detected
- ✅ Network gateway reachable

### VM Readiness

Check VM readiness:

```bash
# Check specific group
./scripts/wait-for-vm-ready.sh masters 192.168.122.11 192.168.122.12 192.168.122.13

# Check K3s API
./scripts/wait-for-vm-ready.sh --k3s-api 192.168.122.11
```

### Log Gathering

Collect comprehensive logs:

```bash
./scripts/gather-logs.sh
```

## 🚨 Common Issues

### 1. Preflight Failures

#### Issue: Missing Required Tools

**Symptoms**:
```
❌ libvirt CLI: Not found
❌ QEMU KVM: Not found
```

**Solutions**:
```bash
# Install libvirt and QEMU
sudo apt update
sudo apt install -y libvirt-daemon-system qemu-kvm

# Add user to libvirt group
sudo usermod -a -G libvirt $USER
newgrp libvirt

# Start libvirt daemon
sudo systemctl start libvirtd
sudo systemctl enable libvirtd
```

#### Issue: Permission Denied

**Symptoms**:
```
❌ libvirt sudo access: No sudo access
❌ virsh list access: No sudo access
```

**Solutions**:
```bash
# Check sudo access
sudo -n virsh version

# If no sudo access, add to libvirt group
sudo usermod -a -G libvirt $USER
newgrp libvirt

# Or configure passwordless sudo for libvirt
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/virsh" | sudo tee /etc/sudoers.d/libvirt
```

#### Issue: Libvirt Daemon Not Running

**Symptoms**:
```
❌ libvirtd service: Not running
```

**Solutions**:
```bash
# Start libvirt daemon
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Check status
sudo systemctl status libvirtd
```

### 2. SSH Connectivity Issues

#### Issue: SSH Key Not Found

**Symptoms**:
```
❌ SSH private key: Not found
```

**Solutions**:
- Set `SSH_PRIVATE_KEY` repository secret
- Or ensure `~/.ssh/id_rsa` exists
- Generate new key: `ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa`

#### Issue: VM Not Reachable

**Symptoms**:
```
❌ SSH connectivity failed to 192.168.122.11 after 30 attempts
```

**Solutions**:
```bash
# Check VM status
virsh list --all | grep k3s-production

# Check VM console
virsh console k3s-production-master-1

# Check network
virsh net-list --all
virsh net-info default

# Check VM IP
virsh net-dhcp-leases default
```

#### Issue: Cloud-init Not Complete

**Symptoms**:
```
❌ Cloud-init failed to complete on 192.168.122.11 after 30 attempts
```

**Solutions**:
```bash
# SSH to VM and check cloud-init status
ssh ubuntu@192.168.122.11 "cloud-init status --wait"

# Check cloud-init logs
ssh ubuntu@192.168.122.11 "sudo journalctl -u cloud-init"

# Check cloud-init user data
ssh ubuntu@192.168.122.11 "sudo cat /var/lib/cloud/instance/user-data.txt"
```

### 3. Terraform Issues

#### Issue: State Lock

**Symptoms**:
```
Error: Error acquiring the state lock
```

**Solutions**:
```bash
# Check for lock file
ls -la /var/lib/libvirt/terraform/k3s-production-cluster/.terraform.tfstate.lock.info

# Remove lock file (if safe)
rm /var/lib/libvirt/terraform/k3s-production-cluster/.terraform.tfstate.lock.info

# Or force unlock
cd terraform
terraform force-unlock <lock-id>
```

#### Issue: Resource Already Exists

**Symptoms**:
```
Error: domain 'k3s-production-master-1' already exists
```

**Solutions**:
```bash
# Check existing VMs
virsh list --all | grep k3s-production

# Clean up manually
for vm in $(virsh list --all --name | grep k3s-production); do
  virsh destroy $vm 2>/dev/null || true
  virsh undefine $vm --remove-all-storage 2>/dev/null || true
done

# Or use force cleanup
gh workflow run deploy-hardened.yml -f force_cleanup=true
```

#### Issue: Provider Not Found

**Symptoms**:
```
Error: Failed to query available provider packages
```

**Solutions**:
```bash
# Initialize Terraform
cd terraform
terraform init

# Check provider versions
terraform version
```

### 4. K3s Issues

#### Issue: API Server Not Ready

**Symptoms**:
```
❌ K3s API failed to start on 192.168.122.11 after 30 attempts
```

**Solutions**:
```bash
# Check K3s service status
ssh ubuntu@192.168.122.11 "sudo systemctl status k3s"

# Check K3s logs
ssh ubuntu@192.168.122.11 "sudo journalctl -u k3s -f"

# Check API server health
curl -k https://192.168.122.11:6443/healthz

# Check node status
kubectl get nodes
```

#### Issue: Nodes Not Ready

**Symptoms**:
```
k3s-production-worker-1   NotReady   <none>   0s
```

**Solutions**:
```bash
# Check node details
kubectl describe node k3s-production-worker-1

# Check pod status
kubectl get pods -A

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check node logs
ssh ubuntu@192.168.122.21 "sudo journalctl -u k3s-agent"
```

#### Issue: Pods Not Starting

**Symptoms**:
```
k3s-production-master-1   Ready     <none>   0s
k3s-production-worker-1   Ready     <none>   0s
# But no pods running
```

**Solutions**:
```bash
# Check pod status
kubectl get pods -A

# Check pod details
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>

# Check cluster info
kubectl cluster-info
```

### 5. Network Issues

#### Issue: IP Collisions

**Symptoms**:
```
❌ 3 IP range(s) have collisions. Please resolve before deploying.
```

**Solutions**:
```bash
# Check IP usage
./scripts/check-ip-collisions.sh

# Check ARP table
arp -n | grep 192.168.122

# Check libvirt DHCP leases
virsh net-dhcp-leases default

# Free up IPs
# Stop conflicting VMs or change IP ranges in terraform/variables.tf
```

#### Issue: Network Not Reachable

**Symptoms**:
```
❌ Network gateway 192.168.122.1 is not reachable
```

**Solutions**:
```bash
# Check network status
virsh net-list --all
virsh net-info default

# Start network
sudo virsh net-start default

# Check network configuration
ip route | grep 192.168.122
```

## 🔧 Advanced Debugging

### Enable Verbose Logging

```bash
# Terraform
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log

# Ansible
ansible-playbook -i inventory.yml playbooks/install-k3s.yaml -vvv

# K3s
ssh ubuntu@192.168.122.11 "sudo journalctl -u k3s -f"
```

### Check Resource Usage

```bash
# Host resources
free -h
df -h
top

# VM resources
ssh ubuntu@192.168.122.11 "free -h"
ssh ubuntu@192.168.122.11 "df -h"
```

### Network Debugging

```bash
# Check network interfaces
ip addr show

# Check routing
ip route show

# Check DNS
nslookup 192.168.122.1

# Check connectivity
ping -c 3 192.168.122.1
```

## 📊 Log Analysis

### Key Log Files

1. **Host System**: `journalctl --since "1 hour ago"`
2. **Libvirt**: `journalctl -u libvirtd --since "1 hour ago"`
3. **VM System**: `ssh ubuntu@<vm-ip> "sudo journalctl --since '1 hour ago'"`
4. **K3s**: `ssh ubuntu@<vm-ip> "sudo journalctl -u k3s --since '1 hour ago'"`
5. **Kubernetes**: `kubectl get events --sort-by='.lastTimestamp'`

### Common Error Patterns

1. **Permission Denied**: Check user groups and sudo access
2. **Connection Refused**: Check service status and network
3. **Resource Exhausted**: Check memory and disk space
4. **Timeout**: Check network connectivity and service health
5. **Already Exists**: Check for existing resources and cleanup

## 🆘 Getting Help

1. **Check Artifacts**: Download and review comprehensive logs
2. **Run Diagnostics**: Use provided diagnostic scripts
3. **Check GitHub Actions**: Review workflow logs
4. **Create Issue**: Include diagnostic output and logs
5. **Community**: Check K3s, Terraform, and Ansible documentation

## 📚 Additional Resources

- [K3s Troubleshooting](https://docs.k3s.io/troubleshooting)
- [Terraform Troubleshooting](https://developer.hashicorp.com/terraform/tutorials/configuration-language/troubleshooting-workflow)
- [Ansible Troubleshooting](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugging.html)
- [Libvirt Troubleshooting](https://libvirt.org/troubleshooting.html)
