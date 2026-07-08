variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://pve01.example.test:8006/api2/json."
  type        = string
}

variable "config_root" {
  description = "Base directory for resolving relative local file inputs such as token and SSH public key files."
  type        = string
  default     = null
}

variable "proxmox_api_token" {
  description = "Proxmox API token in user@realm!token=secret format. Prefer proxmox_api_token_file for local use."
  type        = string
  default     = null
  sensitive   = true
}

variable "proxmox_api_token_file" {
  description = "Path to a file containing the Proxmox API token. Prefer this for local use. Relative paths are resolved from config_root."
  type        = string
  default     = null
}

variable "proxmox_insecure" {
  description = "Allow insecure TLS connections to Proxmox. Keep false unless an explicit private local override is required."
  type        = bool
  default     = false
}

variable "proxmox_node" {
  description = "Default Proxmox node for VM provisioning."
  type        = string
}

variable "default_bridge" {
  description = "Default Proxmox network bridge."
  type        = string
  default     = "vmbr0"
}

variable "default_datastore" {
  description = "Default datastore for cloned VM disks."
  type        = string
  default     = "local-lvm"
}

variable "default_cloud_init_datastore" {
  description = "Default datastore for cloud-init disks."
  type        = string
  default     = "local-lvm"
}

variable "default_scsi_hardware" {
  description = "Default Proxmox SCSI controller hardware type."
  type        = string
  default     = "virtio-scsi-single"

  validation {
    condition     = contains(["lsi", "lsi53c810", "virtio-scsi-pci", "virtio-scsi-single", "megasas", "pvscsi"], var.default_scsi_hardware)
    error_message = "default_scsi_hardware must be one of lsi, lsi53c810, virtio-scsi-pci, virtio-scsi-single, megasas, or pvscsi."
  }
}

variable "default_disk_iothread" {
  description = "Default setting for VM disk IO threads."
  type        = bool
  default     = true
}

variable "default_disk_discard" {
  description = "Default discard/TRIM behavior for VM disks."
  type        = string
  default     = "on"

  validation {
    condition     = contains(["on", "ignore"], var.default_disk_discard)
    error_message = "default_disk_discard must be one of on or ignore."
  }
}

variable "default_disk_cache" {
  description = "Default Proxmox cache mode for VM disks."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "directsync", "writethrough", "writeback", "unsafe"], var.default_disk_cache)
    error_message = "default_disk_cache must be one of none, directsync, writethrough, writeback, or unsafe."
  }
}

variable "default_disk_file_format" {
  description = "Default disk file format for VM disks."
  type        = string
  default     = "raw"

  validation {
    condition     = contains(["raw", "qcow2", "vmdk"], var.default_disk_file_format)
    error_message = "default_disk_file_format must be one of raw, qcow2, or vmdk."
  }
}

variable "default_dns_servers" {
  description = "Default DNS servers advertised through cloud-init."
  type        = list(string)
  default     = []
}

variable "default_dns_search_domain" {
  description = "Default DNS search domain advertised through cloud-init."
  type        = string
  default     = null
}

variable "template_vm_id" {
  description = "Default existing Proxmox template VM ID to clone from."
  type        = number
}

variable "cloud_init_ssh_key_dir" {
  description = "Directory containing generated per-VM cloud-init SSH private keys. Public keys are read from matching .pub files."
  type        = string
  default     = "~/.ssh"
}

variable "cloud_init_ssh_key_prefix" {
  description = "Prefix for generated per-VM cloud-init SSH key names."
  type        = string
  default     = "platform-infra"
}

variable "cloud_init_username" {
  description = "Default cloud-init user account to configure."
  type        = string
  default     = "rocky"
}

variable "agent_enabled" {
  description = "Default setting for Proxmox QEMU guest agent integration."
  type        = bool
  default     = true
}

variable "default_agent_trim" {
  description = "Default setting for QEMU guest agent fstrim integration. Requires a working guest agent and guest support."
  type        = bool
  default     = false
}

variable "vms" {
  description = "VMs to clone from existing Proxmox templates."
  type = map(object({
    vm_id       = number
    hostname    = string
    description = optional(string)
    tags        = optional(list(string), [])

    template_vm_id = optional(number)

    cores              = number
    memory_mb          = number
    memory_floating_mb = optional(number)
    disk_gb            = number

    additional_disks = optional(list(object({
      interface    = string
      size_gb      = number
      datastore_id = optional(string)
      cache        = optional(string)
      discard      = optional(string)
      file_format  = optional(string)
      iothread     = optional(bool)
    })), [])

    datastore_id            = optional(string)
    cloud_init_datastore_id = optional(string)
    boot_disk_interface     = optional(string)
    scsi_hardware           = optional(string)
    disk_iothread           = optional(bool)
    disk_discard            = optional(string)
    disk_cache              = optional(string)
    disk_file_format        = optional(string)
    bridge                  = optional(string)
    ipv4                    = optional(string, "dhcp")
    ipv4_gateway            = optional(string)
    dns_servers             = optional(list(string))
    dns_search_domain       = optional(string)
    ssh_private_key_file    = optional(string)
    ssh_public_key          = optional(string)
    ssh_public_key_file     = optional(string)
    cloud_init_username     = optional(string)
    agent_enabled           = optional(bool)
    agent_trim              = optional(bool)
    cpu_type                = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for _, vm in var.vms : vm.ipv4 == "dhcp" || can(cidrnetmask(vm.ipv4))
    ])
    error_message = "Each VM ipv4 value must be dhcp or an IPv4 address in CIDR notation."
  }

  validation {
    condition = alltrue(flatten([
      for _, vm in var.vms : [
        for disk in vm.additional_disks : disk.size_gb > 0
      ]
    ]))
    error_message = "Each additional disk size_gb value must be greater than zero."
  }
}
