variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, for example https://pve01.example.homelab:8006/api2/json."
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
  description = "Allow insecure TLS connections to Proxmox. Useful for homelab self-signed certificates."
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
    })), [])

    datastore_id            = optional(string)
    cloud_init_datastore_id = optional(string)
    boot_disk_interface     = optional(string)
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
