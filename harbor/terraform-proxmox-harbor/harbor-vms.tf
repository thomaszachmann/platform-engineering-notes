resource "proxmox_virtual_environment_vm" "harbor" {
  for_each = var.harbor_vms

  name      = each.key
  node_name = var.proxmox_node

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    size         = each.value.disk
    interface    = "scsi0"
  }

  network_device {
    bridge = var.vm_network_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      username = "rocky"
      keys     = [var.ssh_public_key]
    }
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
  }

  serial_device {}
}
