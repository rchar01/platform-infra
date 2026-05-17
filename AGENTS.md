# AGENTS.md

Compact guidance for future agent sessions in `platform-infra`.

## Repository Boundary

- This repo owns VM existence and VM shape, not inside-OS configuration.
- This repo provisions Proxmox VMs from templates that already exist.
- Do not add template-building logic, cloud image downloads, `qm importdisk`, OS package installation, `fstab`, NFS mounts, guest firewall rules, Docker/Podman setup, systemd services, Ansible roles, Kubernetes tooling/manifests, CA files, service certificates, backup scripts inside VMs, or application deployment here.
- Template creation belongs in `platform-template-builder`; post-boot VM configuration belongs in `platform-config`.
- Cloud-init here is minimal: hostname, initial user, SSH key, IP addressing, and DNS intent only. Do not use it for complex OS configuration.
- Additional virtual disks may be attached here, but partitioning, formatting, LVM, mounts, and `fstab` belong in `platform-config`.
- Keep the shared platform lifecycle language aligned with `README.md` and `docs/workflow.md` when boundaries change.

## Agent Workflow Expectations

- Read relevant code before editing.
- Prefer minimal changes that match existing patterns.
- Keep `README.md`, `AGENTS.md`, and skill docs current when repository behavior changes.
- If your runtime provides specialized tools or subagents for codebase exploration, use them when the repository structure, ownership boundaries, or relevant files are unclear.
- If your runtime provides specialized tools or subagents for verification, use them for non-trivial test runs, runtime-backed checks, or command-heavy validation.
- If your runtime provides specialized tools or subagents for review, use them after substantial edits to catch regressions, missing updates, or doc/code drift.
- If your runtime provides specialized tools or subagents for research, use them when behavior depends on external tooling or upstream docs.
- Prefer local repository docs, scripts, and configuration first; use web research when local sources are insufficient or freshness matters.
- Summarize any specialist-tool or subagent findings you rely on.
- Do not revert unrelated worktree changes.

## How To Investigate

- Read highest-value sources first: `README.md`, `docs/README.md`, `docs/workflow.md`, `docs/requirements.md`, `docs/state.md`, `.gitignore`, and `environments/*/*.tf`.
- Check for instruction/config files before assuming conventions: `AGENTS.md`, `CLAUDE.md`, `.cursor/rules/`, `.cursorrules`, `.github/copilot-instructions.md`, and `opencode.json`.
- Prefer executable sources of truth over prose. If docs conflict with `.tf` files or ignore rules, trust the executable/config source and update stale docs.
- If architecture is still unclear, inspect representative files in `environments/` and `modules/proxmox-vm/`; there is no top-level OpenTofu root by design.

## OpenTofu Workflow

- Execution roots live under `environments/`; `homelab` and `dev` have independent state.
- Environment `versions.tf` files currently require OpenTofu `>= 1.11.7` and `bpg/proxmox` provider `~> 0.106`.
- Prefer root Make targets for setup only: `make deps`, `make env`, `make init-ssh`, `make init`, `make fmt`, `make validate`.
- Keep Make as the stable public task interface; put multi-step shell logic under `scripts/` and call it from Make.
- `make deps` installs OpenTofu into `~/.local/bin/tofu` by default. Override with `TOFU_INSTALL_DIR`, for example `TOFU_INSTALL_DIR="$PWD/.tools/bin"` in CI.
- `make env` and `make init-ssh` use local ignored config only for fallback testing; pass `PRIVATE=1` for the normal private workflow in `../platform-private/infra`.
- Proxmox tokens for local operator runs normally live in `~/.config/platform-infrastructure/proxmox-token` with `0600` permissions and are referenced by `proxmox_api_token_file`; do not store token values in `platform-private`.
- Proxmox API user/token bootstrap belongs in `platform-tools` (`platform-proxmox-token-init`), not in this repo. This repo consumes an existing token.
- Cloud-init SSH keys are generated under `~/.ssh` by `platform-ssh-init`; private Git stores only the SSH config env file.
- Use native `tofu` for `plan`, `apply`, and `destroy` from the selected environment root with the matching tfvars file.
- For local private workflows, source the matching `../../../platform-private/infra/<env>.tofu.env` file from the selected environment root; it sets `TF_CLI_ARGS_plan`, `TF_CLI_ARGS_apply`, and `TF_CLI_ARGS_destroy` with private config paths.
- Do not run `dev.tfvars` from `environments/homelab` or `homelab.tfvars` from `environments/dev`.
- Normal Make command order:

```bash
make deps
make env ENV=homelab PRIVATE=1
make init-ssh ENV=homelab PRIVATE=1
make fmt
make validate
```

- Direct OpenTofu commands run from the selected environment root.

- Run `tofu apply` or `tofu destroy` only when explicitly requested or clearly required for the task.
- Commit `.terraform.lock.hcl` after successful `tofu init`; do not add it to `.gitignore`.
- Do not commit real `terraform.tfvars`, state files, API tokens, or private SSH keys.
- Prefer `proxmox_api_token_file = "~/.config/platform-infrastructure/proxmox-token"` for local Proxmox credentials so tokens are not exported into long-lived shells.
- Secret-free CI can run `make verify` per environment with `TOFU_INSTALL_DIR="$PWD/.tools/bin"`.
- CI plans that contact Proxmox must inject `TF_VAR_proxmox_api_token` from the CI secret store and use the matching private tfvars for the selected root; keep CI paths explicit per job instead of relying on local `.tofu.env` files.
- Do not use CI apply with ephemeral local state; require remote state with locking first.

## Current Implementation Facts

- `modules/proxmox-vm/` wraps one `proxmox_virtual_environment_vm` cloned from an existing template.
- `environments/homelab/main.tf` and `environments/dev/main.tf` instantiate the module with `for_each = var.vms`.
- `cloud_init_username` defaults to `rocky` for Rocky cloud templates.
- `agent_enabled` defaults to `true`, but the template must actually install and start `qemu-guest-agent`; that responsibility is outside this repo.
- `memory_mb` is the Proxmox maximum memory value; optional per-VM `memory_floating_mb` sets the Proxmox ballooned minimum memory value.
- DHCP is the default network mode. Actual leased IP outputs require a working guest agent.
- Additional virtual disks are infra-owned only until the device exists; guest storage configuration belongs in `platform-config`.
- `ansible_inventory_map` is only a structured handoff for future `platform-config`; do not generate Ansible roles or playbooks here.

## What To Extract During Future Updates

- Exact commands and required working directories.
- Environment-specific gotchas around Proxmox tokens, datastores, bridges, template VM IDs, guest agent behavior, and state files.
- Any changes to platform ownership boundaries or deferred roadmap items.
- Verification limits, especially when OpenTofu or Proxmox access is unavailable locally.
