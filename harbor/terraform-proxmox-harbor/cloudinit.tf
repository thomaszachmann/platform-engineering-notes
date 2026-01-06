resource "proxmox_virtual_environment_file" "cloudinit" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/cloudinit.tpl", {
      hostname = "harbor"
      ssh_key = var.ssh_public_key
    })
    file_name = "cloudinit-harbor.yaml"
  }
}
