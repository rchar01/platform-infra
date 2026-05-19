locals {
  default_tags = ["managed-by-tofu"]
  environment  = "homelab"

  config_root = var.config_root == null ? path.root : (
    startswith(pathexpand(var.config_root), "/")
    ? pathexpand(var.config_root)
    : "${path.root}/${var.config_root}"
  )

  proxmox_api_token_file_path = var.proxmox_api_token_file == null ? null : (
    startswith(pathexpand(var.proxmox_api_token_file), "/")
    ? pathexpand(var.proxmox_api_token_file)
    : "${local.config_root}/${var.proxmox_api_token_file}"
  )

  default_ssh_private_key_files = {
    for name, _ in var.vms : name => "${var.cloud_init_ssh_key_dir}/${var.cloud_init_ssh_key_prefix}-${local.environment}-${name}-cloud-init_ed25519"
  }

  ssh_private_key_files = {
    for name, vm in var.vms : name => coalesce(vm.ssh_private_key_file, local.default_ssh_private_key_files[name])
  }

  ssh_public_key_files = {
    for name, vm in var.vms : name => coalesce(vm.ssh_public_key_file, "${local.ssh_private_key_files[name]}.pub")
  }

  ssh_public_key_file_paths = {
    for name, path in local.ssh_public_key_files : name => (
      startswith(pathexpand(path), "/")
      ? pathexpand(path)
      : "${local.config_root}/${path}"
    )
  }

  proxmox_api_token = var.proxmox_api_token != null ? var.proxmox_api_token : (
    var.proxmox_api_token_file != null ? trimspace(file(local.proxmox_api_token_file_path)) : ""
  )

  ssh_public_keys = {
    for name, vm in var.vms : name => (
      vm.ssh_public_key != null
      ? vm.ssh_public_key
      : try(trimspace(file(local.ssh_public_key_file_paths[name])), "")
    )
  }
}
