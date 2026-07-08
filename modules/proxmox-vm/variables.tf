variable "name" {
  description = "VM hostname/name in Proxmox."
  type        = string
}

variable "vm_id" {
  description = "Numeric Proxmox VM ID for the cloned VM."
  type        = number
}

variable "node_name" {
  description = "Proxmox node where the VM should run."
  type        = string
}

variable "template_vm_id" {
  description = "Existing Proxmox template VM ID to clone from."
  type        = number
}

variable "description" {
  description = "Proxmox VM description."
  type        = string
  default     = "Managed by OpenTofu"
}

variable "tags" {
  description = "Proxmox VM tags."
  type        = list(string)
  default     = []
}

variable "cores" {
  description = "Number of CPU cores."
  type        = number
}

variable "cpu_type" {
  description = "Proxmox CPU type."
  type        = string
  default     = "x86-64-v2-AES"
}

variable "memory_mb" {
  description = "Maximum dedicated memory in megabytes."
  type        = number
}

variable "memory_floating_mb" {
  description = "Optional ballooned minimum memory in megabytes. Omit to keep the provider default."
  type        = number
  default     = null
}

variable "disk_gb" {
  description = "Boot disk size in gigabytes."
  type        = number
}

variable "additional_disks" {
  description = "Additional virtual disks to attach. Guest partitioning and mounts are handled outside this module."
  type = list(object({
    interface    = string
    size_gb      = number
    datastore_id = optional(string)
    cache        = optional(string)
    discard      = optional(string)
    file_format  = optional(string)
    iothread     = optional(bool)
  }))
  default = []

  validation {
    condition = alltrue([
      for disk in var.additional_disks : contains(["none", "directsync", "writethrough", "writeback", "unsafe"], coalesce(disk.cache, "none"))
    ])
    error_message = "Each additional disk cache value must be one of none, directsync, writethrough, writeback, or unsafe."
  }

  validation {
    condition = alltrue([
      for disk in var.additional_disks : contains(["on", "ignore"], coalesce(disk.discard, "on"))
    ])
    error_message = "Each additional disk discard value must be one of on or ignore."
  }

  validation {
    condition = alltrue([
      for disk in var.additional_disks : contains(["raw", "qcow2", "vmdk"], coalesce(disk.file_format, "raw"))
    ])
    error_message = "Each additional disk file_format value must be one of raw, qcow2, or vmdk."
  }
}

variable "datastore_id" {
  description = "Datastore for the cloned VM disk."
  type        = string
}

variable "cloud_init_datastore_id" {
  description = "Datastore for the cloud-init disk."
  type        = string
}

variable "boot_disk_interface" {
  description = "Boot disk interface inherited from the template."
  type        = string
  default     = "scsi0"
}

variable "scsi_hardware" {
  description = "Proxmox SCSI controller hardware type."
  type        = string
  default     = "virtio-scsi-single"

  validation {
    condition     = contains(["lsi", "lsi53c810", "virtio-scsi-pci", "virtio-scsi-single", "megasas", "pvscsi"], var.scsi_hardware)
    error_message = "scsi_hardware must be one of lsi, lsi53c810, virtio-scsi-pci, virtio-scsi-single, megasas, or pvscsi."
  }
}

variable "disk_iothread" {
  description = "Enable IO thread for VM disks by default."
  type        = bool
  default     = true
}

variable "disk_discard" {
  description = "Default discard/TRIM behavior for VM disks."
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "ignore"], var.disk_discard)
    error_message = "disk_discard must be one of on or ignore."
  }
}

variable "disk_cache" {
  description = "Default Proxmox cache mode for VM disks."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "directsync", "writethrough", "writeback", "unsafe"], var.disk_cache)
    error_message = "disk_cache must be one of none, directsync, writethrough, writeback, or unsafe."
  }
}

variable "disk_file_format" {
  description = "Default disk file format for VM disks."
  type        = string
  default     = "raw"

  validation {
    condition     = contains(["raw", "qcow2", "vmdk"], var.disk_file_format)
    error_message = "disk_file_format must be one of raw, qcow2, or vmdk."
  }
}

variable "bridge" {
  description = "Proxmox network bridge."
  type        = string
}

variable "ipv4" {
  description = "IPv4 cloud-init address. Use dhcp or CIDR notation."
  type        = string
  default     = "dhcp"

  validation {
    condition     = var.ipv4 == "dhcp" || can(cidrnetmask(var.ipv4))
    error_message = "ipv4 must be dhcp or an IPv4 address in CIDR notation."
  }
}

variable "ipv4_gateway" {
  description = "IPv4 gateway for static IPv4 configuration. Omit when ipv4 is dhcp."
  type        = string
  default     = null
}

variable "dns_servers" {
  description = "DNS servers to advertise through cloud-init."
  type        = list(string)
  default     = []
}

variable "dns_search_domain" {
  description = "DNS search domain to advertise through cloud-init."
  type        = string
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key injected into the cloud-init user account."
  type        = string

  validation {
    condition     = length(trimspace(var.ssh_public_key)) > 0
    error_message = "ssh_public_key must not be empty. Run make init-ssh for the selected environment or set a per-VM ssh_public_key/ssh_public_key_file override."
  }
}

variable "cloud_init_username" {
  description = "Cloud-init user account to configure."
  type        = string
  default     = "rocky"
}

variable "agent_enabled" {
  description = "Enable Proxmox QEMU guest agent integration for this VM."
  type        = bool
  default     = true
}

variable "agent_trim" {
  description = "Enable QEMU guest agent fstrim integration. Requires a working guest agent and guest support."
  type        = bool
  default     = false
}
