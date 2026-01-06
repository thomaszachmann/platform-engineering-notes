#cloud-config
hostname: ${hostname}

users:
  - name: rocky
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_key}

package_update: true
packages:
  - vim
  - curl
  - git
  - podman
  - firewalld

runcmd:
  - systemctl enable --now firewalld
  - systemctl enable --now podman
