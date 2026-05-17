output "name" {
  description = "VM name."
  value       = proxmox_virtual_environment_vm.this.name
}

output "vm_id" {
  description = "Proxmox VM ID."
  value       = proxmox_virtual_environment_vm.this.vm_id
}

output "ipv4_addresses" {
  description = "IPv4 addresses reported by the guest agent, when available."
  value       = try(proxmox_virtual_environment_vm.this.ipv4_addresses, [])
}

output "mac_addresses" {
  description = "MAC addresses reported by Proxmox."
  value       = try(proxmox_virtual_environment_vm.this.mac_addresses, [])
}
