locals {
  default_tags = ["managed-by-tofu"]

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

  ssh_public_key_file_path = var.ssh_public_key_file == null ? null : (
    startswith(pathexpand(var.ssh_public_key_file), "/")
    ? pathexpand(var.ssh_public_key_file)
    : "${local.config_root}/${var.ssh_public_key_file}"
  )

  proxmox_api_token = var.proxmox_api_token != null ? var.proxmox_api_token : (
    var.proxmox_api_token_file != null ? trimspace(file(local.proxmox_api_token_file_path)) : ""
  )

  ssh_public_key = var.ssh_public_key != null ? var.ssh_public_key : (
    var.ssh_public_key_file != null ? trimspace(file(local.ssh_public_key_file_path)) : ""
  )
}
