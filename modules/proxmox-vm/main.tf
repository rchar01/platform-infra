resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  description = var.description
  tags        = sort(distinct(var.tags))

  node_name = var.node_name
  vm_id     = var.vm_id

  clone {
    vm_id        = var.template_vm_id
    datastore_id = var.datastore_id
    full         = true
    retries      = 3
  }

  agent {
    enabled = var.agent_enabled
    trim    = var.agent_trim
  }

  stop_on_destroy = true
  scsi_hardware   = var.scsi_hardware

  cpu {
    cores = var.cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
    floating  = var.memory_floating_mb
  }

  disk {
    datastore_id = var.datastore_id
    cache        = var.disk_cache
    discard      = var.disk_discard
    file_format  = var.disk_file_format
    interface    = var.boot_disk_interface
    iothread     = var.disk_iothread
    size         = var.disk_gb
  }

  dynamic "disk" {
    for_each = var.additional_disks

    content {
      datastore_id = coalesce(disk.value.datastore_id, var.datastore_id)
      cache        = coalesce(disk.value.cache, var.disk_cache)
      discard      = coalesce(disk.value.discard, var.disk_discard)
      file_format  = coalesce(disk.value.file_format, var.disk_file_format)
      interface    = disk.value.interface
      iothread     = coalesce(disk.value.iothread, var.disk_iothread)
      size         = disk.value.size_gb
    }
  }

  initialization {
    datastore_id = var.cloud_init_datastore_id

    ip_config {
      ipv4 {
        address = var.ipv4
        gateway = var.ipv4 == "dhcp" ? null : var.ipv4_gateway
      }
    }

    dynamic "dns" {
      for_each = length(var.dns_servers) > 0 || var.dns_search_domain != null ? [1] : []

      content {
        domain  = var.dns_search_domain
        servers = var.dns_servers
      }
    }

    user_account {
      username = var.cloud_init_username
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

  network_device {
    bridge = var.bridge
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  lifecycle {
    precondition {
      condition     = !var.agent_trim || var.agent_enabled
      error_message = "agent_trim requires agent_enabled to be true."
    }
  }
}
