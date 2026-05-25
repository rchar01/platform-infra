# Homelab Environment

This is the first OpenTofu execution root for `platform-infra`. It has independent state and must use homelab configuration only.

Use `../../docs/workflow.md` for the canonical step-by-step setup, plan, apply, destroy, and fallback workflows.

## Private Config

The normal private workflow uses:

- `../../../platform-private/infra/homelab.tfvars`.
- `../../../platform-private/infra/homelab.tofu.env`.
Source `homelab.tofu.env` from this root before native OpenTofu operations. It supplies `homelab.tfvars` and `config_root` through OpenTofu CLI args.

Run `make init-ssh ENV=homelab PRIVATE=1` from the repository root after editing `homelab.tfvars`. It generates one cloud-init SSH keypair per VM using the default `~/.ssh/platform-infra-homelab-<vm-key>-cloud-init_ed25519` path pattern.

OpenTofu auto-loads `terraform.tfvars` from this directory. If using the private workflow, keep local `terraform.tfvars` absent or free of conflicting token-related values.

Do not run `dev.tfvars` from this root. `environments/dev` has its own independent state.

## Notes

- The template VM ID must already exist in Proxmox.
- `terraform.tfvars.example` shows an example static bastion at `192.0.2.50/24`.
- Extra virtual disks may be attached here; partitioning, formatting, LVM, mounts, and `fstab` belong in `platform-config`.
- The actual DHCP lease is only available in outputs when `qemu-guest-agent` is installed and running in the guest and `agent_enabled = true`.
- If the first test template does not have a working guest agent, set `agent_enabled = false` before applying.
