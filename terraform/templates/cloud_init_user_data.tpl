#cloud-config
# K3s Production Cluster - Cloud Init User Data
# Based on Ubuntu 24.04 LTS cloud-init best practices

hostname: ${hostname}
fqdn: ${hostname}.k3s.local
manage_etc_hosts: true

users:
  - name: ubuntu
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${public_key}

# Disable password authentication
ssh_pwauth: false

# Update system packages
package_update: true
package_upgrade: true

# Install essential packages
packages:
  - curl
  - wget
  - git
  - vim
  - htop
  - net-tools
  - dnsutils
  - jq
  - unzip
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - qemu-guest-agent

# Configure timezone
timezone: UTC

# Run commands on first boot
runcmd:
  # Enable qemu-guest-agent
  - systemctl enable --now qemu-guest-agent
  
  # Update system
  - apt-get update
  - apt-get upgrade -y
  
  # Install Docker
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  
  # Install kubectl
  - curl -LO "https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - chmod +x kubectl
  - mv kubectl /usr/local/bin/
  
  # Install Helm
  - curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null
  - echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | tee /etc/apt/sources.list.d/helm-stable-debian.list
  - apt-get update
  - apt-get install -y helm
  
  # Configure system limits
  - echo "* soft nofile 65536" >> /etc/security/limits.conf
  - echo "* hard nofile 65536" >> /etc/security/limits.conf
  - echo "* soft nproc 65536" >> /etc/security/limits.conf
  - echo "* hard nproc 65536" >> /etc/security/limits.conf
  
  # Configure kernel parameters for Kubernetes
  - echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.conf
  - echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf
  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  - sysctl -p
  
  # Load required kernel modules
  - echo "br_netfilter" >> /etc/modules
  - echo "overlay" >> /etc/modules
  - modprobe br_netfilter
  - modprobe overlay
  
  # Disable swap
  - swapoff -a
  - sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
  
  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default | tee /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  
  # Create k3s user
  - useradd -r -s /bin/false -m -d /var/lib/rancher/k3s k3s
  
  # Set hostname
  - hostnamectl set-hostname ${hostname}

# Final message
final_message: "K3s node ${hostname} is ready! SSH access available for ubuntu user."
