# K3s Production Cluster - Cloud Init Network Config
# Based on Ubuntu 24.04 LTS cloud-init best practices

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