# Dev Environment

This OpenTofu root manages the independent `dev` VM set. It has separate state from `environments/homelab`.

Use `../../docs/workflow.md` for the canonical step-by-step setup, plan, apply, destroy, and fallback workflows.

## Private Config

The normal private workflow uses:

- `../../../platform-private/infra/dev.tfvars`.
- `../../../platform-private/infra/dev.tofu.env`.
Source `dev.tofu.env` from this root before native OpenTofu operations. It supplies `dev.tfvars` and `config_root` through OpenTofu CLI args.

Run `make init-ssh ENV=dev PRIVATE=1` from the repository root after editing `dev.tfvars`. It generates one cloud-init SSH keypair per VM using the default `~/.ssh/platform-infra-dev-<vm-key>-cloud-init_ed25519` path pattern.

OpenTofu auto-loads `terraform.tfvars` from this directory. If using the private workflow, keep local `terraform.tfvars` absent or free of conflicting token-related values.

Do not run `dev.tfvars` from the `homelab` root. Each environment root owns its own state.
