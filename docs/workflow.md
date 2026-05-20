# Workflow

This is the canonical step-by-step workflow guide for `platform-infra`.

Use this document for local operator setup, private configuration, environment-specific OpenTofu commands, fallback testing, destroy operations, and CI workflow shape.

## Overview

The platform split is lifecycle-based:

```text
platform-template-builder -> platform-infra -> platform-config
```

| Repository | Workflow Role |
| --- | --- |
| `platform-template-builder` | Builds Proxmox templates. |
| `platform-infra` | Clones templates and manages VM lifecycle. |
| `platform-config` | Configures VMs after boot. |
| `platform-k8s-bastion` | Provides Kubernetes access tooling. |
| `platform-docs` | Stores design notes and runbooks. |

`platform-infra` starts after a Proxmox template exists and stops after VMs exist with initial cloud-init access and OpenTofu outputs for handoff.

## Safety Rules

- Run Make setup helpers from the repository root.
- Run native `tofu` commands from the selected environment root.
- Use `environments/homelab` only with `homelab.tfvars` and homelab state.
- Use `environments/dev` only with `dev.tfvars` and dev state.
- Do not keep a local `environments/<env>/terraform.tfvars` file for the normal private workflow.
- Do not commit real tfvars, state files, plan files, Proxmox tokens, or SSH private keys.
- Run `tofu apply` and `tofu destroy` only after reviewing the selected environment and plan.

OpenTofu automatically loads `terraform.tfvars` from the current root. A stale local file can conflict with the private tfvars supplied by `../platform-private/infra/<env>.tfvars`.

## Prerequisites

Confirm these before running the first plan:

- A Proxmox template VM already exists.
- The target Proxmox node, bridge, and datastores are known.
- A Proxmox API token exists or can be created. The initial apply identity is documented in `proxmox-api-token.md`.
- The sibling private repo exists at `../platform-private` or will be created before private config is committed.
- Optional `platform-tools` helpers are installed if you want to use `platform-proxmox-token-init` or `platform-ssh-init`.

Install the repo-pinned OpenTofu binary:

```bash
make deps
```

By default this installs `~/.local/bin/tofu`. Use `TOFU_INSTALL_DIR` when you need a different location:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

## One-Time Local Private Setup

Create the local token directory outside Git:

```bash
mkdir -p ~/.config/platform-infrastructure
chmod 700 ~/.config/platform-infrastructure
```

Bootstrap the Proxmox API identity from the operator workstation over SSH. Check prerequisites first:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user tofu@pve \
  --token-id homelab \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/proxmox-token \
  --check
```

Then run the same command without `--check`:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user tofu@pve \
  --token-id homelab \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/proxmox-token
```

Use the Proxmox IP address until a trusted hostname or SSH alias exists. `root@pve` only works when `pve` resolves through DNS, `/etc/hosts`, or a `Host pve` block in `~/.ssh/config`.

The token file should contain only the Proxmox token value:

```text
tofu@pve!homelab=TOKEN_SECRET
```

If the local token file is already non-empty, the automatic workflow refuses to overwrite it. Use `--force` only when intentionally replacing the token file. If the token already exists in Proxmox, Proxmox cannot show the existing secret; delete and recreate the token if the secret was lost.

Create or refresh the private homelab config and per-VM cloud-init SSH keys:

```bash
make env ENV=homelab PRIVATE=1
$EDITOR ../platform-private/infra/homelab.tfvars
make init-ssh ENV=homelab PRIVATE=1
```

Create or refresh the private dev config and per-VM cloud-init SSH keys when needed:

```bash
make env ENV=dev PRIVATE=1
$EDITOR ../platform-private/infra/dev.tfvars
make init-ssh ENV=dev PRIVATE=1
```

The private tfvars files should reference the token file path, not the token value:

```hcl
proxmox_api_token_file = "~/.config/platform-infrastructure/proxmox-token"
```

The scaffolded examples use `proxmox_insecure = false` so Proxmox API TLS verification is enabled by default. Prefer trusting the Proxmox API certificate from the operator workstation and CI runners. Use `proxmox_insecure = true` only as an explicit private/local override for a known self-signed setup after accepting the MITM and token exposure risk.

Expected private layout:

```text
../platform-private/infra/
  homelab.tfvars
  dev.tfvars
  homelab.tofu.env
  dev.tofu.env
```

The `.tofu.env` files contain no secrets. They set `TF_CLI_ARGS_plan`, `TF_CLI_ARGS_apply`, and `TF_CLI_ARGS_destroy` so local operator commands use the matching private tfvars and `config_root`.

`make init-ssh` reads the selected environment's `vms` map and generates one local cloud-init SSH keypair per VM with `platform-ssh-init`. The default key path pattern is:

```text
~/.ssh/platform-infra-<env>-<vm-key>-cloud-init_ed25519
```

OpenTofu reads the matching `.pub` file for each VM during planning and injects it through cloud-init. The private key path is exposed in `ansible_inventory_map` for `platform-config` handoff.

## Homelab Workflow

Run setup helpers from the repository root:

```bash
make deps
make env ENV=homelab PRIVATE=1
make init-ssh ENV=homelab PRIVATE=1
make validate ENV=homelab
```

Run OpenTofu from the homelab root:

```bash
cd environments/homelab
source "../../../platform-private/infra/homelab.tofu.env"

~/.local/bin/tofu init
~/.local/bin/tofu validate
~/.local/bin/tofu plan
```

Apply only after reviewing the plan:

```bash
~/.local/bin/tofu apply
```

Inspect outputs for handoff to `platform-config`:

```bash
~/.local/bin/tofu output
```

The `ansible_inventory_map` output includes `ansible_host`, `ansible_user`, and `ansible_ssh_private_key_file` values for each VM.

## Dev Workflow

Run setup helpers from the repository root:

```bash
make deps
make env ENV=dev PRIVATE=1
make init-ssh ENV=dev PRIVATE=1
make validate ENV=dev
```

Run OpenTofu from the dev root:

```bash
cd environments/dev
source "../../../platform-private/infra/dev.tofu.env"

~/.local/bin/tofu init
~/.local/bin/tofu validate
~/.local/bin/tofu plan
```

Apply only after reviewing the plan:

```bash
~/.local/bin/tofu apply
```

## Switching Environments

Use a new shell or source the matching env file whenever switching environment roots:

The relative `../../../platform-private/...` path assumes the command is run from an `environments/<env>` root.

```bash
cd environments/homelab
source "../../../platform-private/infra/homelab.tofu.env"
```

```bash
cd environments/dev
source "../../../platform-private/infra/dev.tofu.env"
```

Do not run `dev.tfvars` from `environments/homelab`, and do not run `homelab.tfvars` from `environments/dev`. Each root has independent state and an independent VM set.

## Review and Apply

Before applying, confirm the selected root and private tfvars:

```bash
pwd
env | grep '^TF_CLI_ARGS_'
~/.local/bin/tofu plan
```

A safe apply sequence is:

```bash
~/.local/bin/tofu plan -out=reviewed.tfplan
~/.local/bin/tofu apply reviewed.tfplan
rm -f reviewed.tfplan
```

Plan files can contain sensitive or environment-specific values. Do not commit them.

## Destroy

Destroy only from the selected environment root after sourcing the matching `.tofu.env` file.

Homelab destroy:

```bash
cd environments/homelab
source "../../../platform-private/infra/homelab.tofu.env"

~/.local/bin/tofu state list
~/.local/bin/tofu plan -destroy -out=destroy.tfplan
~/.local/bin/tofu apply destroy.tfplan
rm -f destroy.tfplan
~/.local/bin/tofu state list
```

Use `environments/dev` and `dev.tofu.env` for dev destroys.

Prefer this over deleting VMs manually in Proxmox. Manual deletion leaves OpenTofu state stale and requires state repair.

## Validation-Only Workflow

Use this before review or commit. It does not contact Proxmox and does not need private tfvars:

```bash
make verify TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=dev TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

Equivalent local checks with the default install path are:

```bash
make verify
make verify ENV=dev
```

## Local Fallback Workflow

The fallback workflow is for isolated testing only. It is not the normal private workflow.

From an environment root:

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
tofu init
tofu validate
tofu plan -var-file="$PWD/terraform.tfvars" -var="config_root=$PWD"
```

Remove the fallback file before returning to the private workflow if it contains conflicting values:

```bash
rm terraform.tfvars
```

## CI Validation Workflow

Secret-free CI validation can run on every pull request:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=dev TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

This validates formatting, initialization, and static OpenTofu configuration without private tfvars or Proxmox credentials.

## CI Proxmox Plan Workflow

Proxmox-backed CI plan jobs should run one environment at a time. They should keep `-var-file` and `config_root` explicit instead of relying on local `.tofu.env` files.

Homelab plan job body:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/homelab
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu plan -input=false -out=homelab.tfplan \
  -var-file="$PWD/../../../platform-private/infra/homelab.tfvars" \
  -var="config_root=$PWD/../../../platform-private/infra"
```

Dev plan job body:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/dev
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu plan -input=false -out=dev.tfplan \
  -var-file="$PWD/../../../platform-private/infra/dev.tfvars" \
  -var="config_root=$PWD/../../../platform-private/infra"
```

Inject `TF_VAR_proxmox_api_token` from the CI secret store for Proxmox-backed jobs. Do not write token values to `platform-private`, logs, artifacts, or committed files.

Saved plan files can contain sensitive values. Store them only as protected, short-lived artifacts.

## CI Apply Requirements

CI apply is not production-grade with ephemeral local state. Before using CI apply, add:

- Remote OpenTofu state with encryption.
- State locking.
- Backend credentials for both plan and apply jobs.
- Restricted access to state and CI secrets.
- Protected branch or tag rules.
- Manual approval before apply.
- Separate jobs per environment.
- No cross-use of tfvars between roots.

Apply jobs should apply a reviewed saved plan non-interactively:

```bash
cd environments/homelab
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu apply -input=false homelab.tfplan
```

See `ci.md` for the detailed CI reference.

## Handoff to platform-config

After apply, `platform-config` configures the running VM. It should consume outputs from this repository and must not be implemented here.

The first structured handoff output is:

```bash
~/.local/bin/tofu output ansible_inventory_map
```

When DHCP is used, actual leased IP outputs require a working `qemu-guest-agent` in the template.

## Boundary

Do not add template-building logic, Ansible playbooks, Kubernetes scripts, Kubernetes manifests, certificate authority files, service certificates, `fstab`, NFS mounts, partitioning/formatting/mounting of attached disks, Docker/Podman setup, systemd services, backup scripts inside VMs, or application deployment code to this repository.
