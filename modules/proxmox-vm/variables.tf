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
  }))
  default = []
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
