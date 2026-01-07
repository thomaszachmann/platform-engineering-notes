output "vm_ip_addresses" {
  description = "IP addresses of all Gitlab VMs"
  value = {
    for vm_name, vm in proxmox_virtual_environment_vm.gitlab :
    vm_name => {
      vm_id       = vm.vm_id
      ip_address  = length(vm.ipv4_addresses) > 1 ? vm.ipv4_addresses[1][0] : "IP not available yet"
      ssh_command = length(vm.ipv4_addresses) > 1 ? "ssh rocky@${vm.ipv4_addresses[1][0]}" : "Waiting for IP..."
    }
  }
}

output "vm_summary" {
  description = "Summary of all VMs"
  value = <<-EOT

  Gitlab VMs erfolgreich erstellt!
  ================================

  ${join("\n  ", [for vm_name, vm in proxmox_virtual_environment_vm.gitlab :
  length(vm.ipv4_addresses) > 1 ?
  "${vm_name} (VM ID: ${vm.vm_id})\n    IP: ${vm.ipv4_addresses[1][0]}\n    SSH: ssh rocky@${vm.ipv4_addresses[1][0]}" :
  "${vm_name} (VM ID: ${vm.vm_id})\n    IP: Warte auf DHCP..."
])}

  EOT
}
