variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type    = string
  default = "pve01"
}

variable "vm_network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "vm_storage" {
  type    = string
  default = "local-lvm"
}

variable "ssh_public_key" {
  type = string
}

variable "harbor_vms" {
  type = map(object({
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
}
