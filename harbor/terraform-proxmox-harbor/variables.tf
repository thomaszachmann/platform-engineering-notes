variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint (e.g., https://192.168.1.100:8006)"
  default     = "https://172.16.0.162:8006"
}

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

variable "template_vm_id" {
  type        = number
  description = "VM ID of the cloud-init template to clone from"
}

variable "harbor_vms" {
  type = map(object({
    cores  = number
    memory = number
    disk   = number
  }))
}
