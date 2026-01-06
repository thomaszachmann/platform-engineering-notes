proxmox_api_token = "terraform@pve!token=xxxxxxxx"

ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."

harbor_vms = {
  harbor-01 = {
    ip     = "10.10.10.11/24"
    cores  = 4
    memory = 8192
    disk   = 40
  }
  harbor-02 = {
    ip     = "10.10.10.12/24"
    cores  = 4
    memory = 8192
    disk   = 40
  }
  harbor-data = {
    ip     = "10.10.10.20/24"
    cores  = 4
    memory = 16384
    disk   = 200
  }
}
