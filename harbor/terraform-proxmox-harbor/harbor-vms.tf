resource "proxmox_virtual_environment_vm" "harbor" {
  for_each = var.harbor_vms

  name      = each.key
  node_name = var.proxmox_node

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = var.vm_storage
    size         = "${each.value.disk}G"
    interface    = "scsi0"
  }

  network_device {
    bridge = var.vm_network_bridge
  }

  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = "10.10.10.1"
      }
    }

    user_account {
      username = "rocky"
      keys     = [var.ssh_public_key]
    }

    user_data_file_id = proxmox_virtual_environment_file.cloudinit.id
  }

  operating_system {
    type = "l26"
  }
}
