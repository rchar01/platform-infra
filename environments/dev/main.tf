module "vm" {
  source = "../../modules/proxmox-vm"

  for_each = var.vms

  name        = each.value.hostname
  vm_id       = each.value.vm_id
  node_name   = var.proxmox_node
  description = coalesce(each.value.description, "Managed by OpenTofu")
  tags        = concat(local.default_tags, each.value.tags)

  template_vm_id = coalesce(each.value.template_vm_id, var.template_vm_id)

  cores              = each.value.cores
  cpu_type           = coalesce(each.value.cpu_type, "x86-64-v2-AES")
  memory_mb          = each.value.memory_mb
  memory_floating_mb = each.value.memory_floating_mb
  disk_gb            = each.value.disk_gb

  additional_disks = each.value.additional_disks

  datastore_id            = coalesce(each.value.datastore_id, var.default_datastore)
  cloud_init_datastore_id = coalesce(each.value.cloud_init_datastore_id, var.default_cloud_init_datastore)
  boot_disk_interface     = coalesce(each.value.boot_disk_interface, "scsi0")
  bridge                  = coalesce(each.value.bridge, var.default_bridge)

  ipv4         = each.value.ipv4
  ipv4_gateway = each.value.ipv4_gateway

  dns_servers       = coalesce(each.value.dns_servers, var.default_dns_servers)
  dns_search_domain = coalesce(each.value.dns_search_domain, var.default_dns_search_domain)

  ssh_public_key      = local.ssh_public_key
  cloud_init_username = coalesce(each.value.cloud_init_username, var.cloud_init_username)
  agent_enabled       = coalesce(each.value.agent_enabled, var.agent_enabled)
}
