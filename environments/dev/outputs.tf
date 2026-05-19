output "vm_names" {
  description = "VM names by inventory key."
  value = {
    for name, vm in module.vm : name => vm.name
  }
}

output "vm_ids" {
  description = "Proxmox VM IDs by inventory key."
  value = {
    for name, vm in module.vm : name => vm.vm_id
  }
}

output "vm_ipv4_config" {
  description = "Configured IPv4 mode or address by inventory key. DHCP does not expose the actual lease unless the guest agent reports it."
  value = {
    for name, vm in var.vms : name => vm.ipv4
  }
}

output "vm_reported_ipv4_addresses" {
  description = "IPv4 addresses reported by the QEMU guest agent, when available."
  value = {
    for name, vm in module.vm : name => vm.ipv4_addresses
  }
}

output "ansible_inventory_map" {
  description = "Structured output for later platform-config inventory generation."
  value = {
    for name, vm in var.vms : name => {
      hostname                     = vm.hostname
      ipv4                         = vm.ipv4
      primary_ip                   = vm.ipv4 == "dhcp" ? null : split("/", vm.ipv4)[0]
      ansible_host                 = vm.ipv4 == "dhcp" ? null : split("/", vm.ipv4)[0]
      user                         = coalesce(vm.cloud_init_username, var.cloud_init_username)
      ansible_user                 = coalesce(vm.cloud_init_username, var.cloud_init_username)
      ansible_ssh_private_key_file = local.ssh_private_key_files[name]
      vm_id                        = vm.vm_id
      agent_enabled                = coalesce(vm.agent_enabled, var.agent_enabled)
      dns_servers                  = coalesce(vm.dns_servers, var.default_dns_servers)
      dns_search_domain            = coalesce(vm.dns_search_domain, var.default_dns_search_domain)
      additional_disks             = vm.additional_disks
    }
  }
}
