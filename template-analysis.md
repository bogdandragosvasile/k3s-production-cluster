# Template and Delegation Analysis

## 🔍 **ISSUES IDENTIFIED**

### 1. **Network Configuration Template Issues**
- **File**: `terraform/templates/cloud_init_network_config.tpl`
- **Issue**: Uses hardcoded `ens3` interface name
- **Problem**: VMs might have different interface names (enp0s3, eth0, etc.)
- **Fix Needed**: Use flexible interface matching like `match: name: en*`

### 2. **Ansible Playbook Issues**
- **File**: `ansible/playbooks/install-k3s.yaml`
- **Issue**: Hardcoded IP addresses and inconsistent server IP
- **Problems**:
  - `k3s_server_ip: "192.168.122.241"` (should be `192.168.122.11`)
  - `k3s_server_ip: "192.168.122.11"` (inconsistent)
  - Missing `k3s_token` retrieval from first master
  - Host group names don't match inventory (loadbalancers vs load_balancers)

### 3. **Terraform to Ansible Delegation Issues**
- **Issue**: No automatic kubeconfig retrieval
- **Problem**: Ansible can't access kubectl without kubeconfig
- **Missing**: Kubeconfig download and setup

### 4. **Cloud-init Template Issues**
- **File**: `terraform/templates/cloud_init_user_data.tpl`
- **Issue**: Uses `ssh_public_key` but template expects `public_key`
- **Problem**: Variable name mismatch

## ✅ **WHAT'S WORKING**

### 1. **Terraform Infrastructure**
- ✅ VM provisioning with libvirt
- ✅ Cloud-init disk generation
- ✅ Static IP assignment
- ✅ Inventory generation

### 2. **Ansible Inventory**
- ✅ Proper YAML format
- ✅ Correct host groups
- ✅ SSH configuration

### 3. **Basic Workflow**
- ✅ Terraform → Ansible delegation
- ✅ Static IP configuration
- ✅ SSH key injection

## 🛠️ **FIXES NEEDED**

### 1. **Fix Network Template**
```yaml
# terraform/templates/cloud_init_network_config.tpl
network:
  version: 2
  ethernets:
    primary-nic:
      match:
        name: en*
      dhcp4: false
      dhcp6: false
      addresses:
        - ${ip}/24
      gateway4: ${gateway}
      nameservers:
        addresses:
          - ${dns}
          - 8.8.4.4
```

### 2. **Fix Ansible Playbook**
- Fix hardcoded IP addresses
- Add kubeconfig retrieval
- Fix host group names
- Add proper token handling

### 3. **Fix Cloud-init Template**
- Fix variable name from `ssh_public_key` to `public_key`

### 4. **Add Kubeconfig Management**
- Add task to download kubeconfig from first master
- Add kubectl setup for Ansible controller

## 🚨 **CRITICAL ISSUES**

1. **Network Interface Mismatch**: VMs won't get network configuration
2. **IP Address Inconsistency**: K3s won't connect properly
3. **Missing Kubeconfig**: Can't manage cluster after deployment
4. **Variable Name Mismatch**: Cloud-init won't work

## 📋 **PRIORITY FIXES**

1. **HIGH**: Fix network template for interface matching
2. **HIGH**: Fix Ansible playbook IP addresses
3. **MEDIUM**: Add kubeconfig management
4. **LOW**: Fix variable name consistency
