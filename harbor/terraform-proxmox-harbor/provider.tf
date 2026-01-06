provider "proxmox" {
  endpoint = "https://proxmox.example.local:8006"
  api_token = var.proxmox_api_token
  insecure  = true
}
