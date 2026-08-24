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
- Use `environments/config-test` only with `config-test.tfvars` and its disposable acceptance state.
- Use `environments/snapshot-test` only with `snapshot-test.tfvars` and its disposable acceptance state.
- Use `environments/migration-test` only with `migration-test.tfvars` and its disposable acceptance state.
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
- Recommended `platform-tools` helpers are installed for normal local setup: `platform-config-init`, `platform-proxmox-token-init`, and `platform-ssh-init`.

## Infra Initialization Summary

Run setup helpers from the repository root. Run native `tofu` commands from the selected environment root.

Install the repo-pinned OpenTofu version:

```bash
make deps
```

Override the OpenTofu version or install directory when needed:

```bash
make deps TOFU_VERSION=1.11.7 TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

Initialize local private config, credentials, environment values, and per-VM SSH keys:

```bash
platform-config-init
platform-proxmox-token-init ... --check
platform-proxmox-token-init ...

make env ENV=<env> PRIVATE=1
$EDITOR ../platform-private/infra/<env>.tfvars
make init-ssh ENV=<env> PRIVATE=1
make validate ENV=<env>
```

Run OpenTofu from the selected environment root:

```bash
cd environments/<env>
source "../../../platform-private/infra/<env>.tofu.env"

~/.local/bin/tofu init
~/.local/bin/tofu validate
~/.local/bin/tofu plan
```

Only run `tofu apply` after reviewing the selected environment, tfvars, state root, and plan.

Install the repo-pinned OpenTofu binary:

```bash
make deps
```

By default this installs `~/.local/bin/tofu`. Use `TOFU_VERSION` or `TOFU_INSTALL_DIR` when you need a different version or location:

```bash
make deps TOFU_VERSION=1.11.7 TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

## One-Time Local Private Setup

Provision the local outside-Git security-sensitive namespace with `platform-tools`:

```bash
platform-config-init
```

The initializer creates only the protected `infra/`, `config/`, and `pki/`
namespaces plus its README. It intentionally creates no placeholder token or
secret files; use the owning helper to publish each concrete input.

If `platform-config-init` is unavailable, create the base directory manually as a fallback:

```bash
mkdir -p ~/.config/platform-infrastructure
chmod 700 ~/.config/platform-infrastructure
```

Bootstrap the Proxmox API identity from the operator workstation over SSH. Check prerequisites first:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user <automation-user>@<realm> \
  --token-id <token-id> \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/infra/proxmox.token \
  --check
```

Then run the same command without `--check`:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user <automation-user>@<realm> \
  --token-id <token-id> \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/infra/proxmox.token
```

The token helper creates the `infra/` parent directory when writing the token file.

Use the Proxmox IP address until a trusted hostname or SSH alias exists. `root@pve` only works when `pve` resolves through DNS, `/etc/hosts`, or a `Host pve` block in `~/.ssh/config`.

The token file should contain only the Proxmox token value:

```text
<automation-user>@<realm>!<token-id>=TOKEN_SECRET
```

If the local token file is already non-empty, the automatic workflow refuses to overwrite it. Use `--force` only when intentionally replacing the token file. If the token already exists in Proxmox, Proxmox cannot show the existing secret; delete and recreate the token if the secret was lost.

Create or refresh the private `homelab` environment config and per-VM cloud-init SSH keys:

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

Create or refresh the disposable snapshot-test config and keys only for a live
acceptance run:

```bash
make env ENV=snapshot-test PRIVATE=1
$EDITOR ../platform-private/infra/snapshot-test.tfvars
make init-ssh ENV=snapshot-test PRIVATE=1
```

Create or refresh the disposable config-test config and key only for an isolated
`platform-config` acceptance campaign:

```bash
make env ENV=config-test PRIVATE=1
$EDITOR ../platform-private/infra/config-test.tfvars
make init-ssh ENV=config-test PRIVATE=1
```

Create or refresh the disposable migration-test config and keys only for a
consumer-owned migration campaign:

```bash
make env ENV=migration-test PRIVATE=1
$EDITOR ../platform-private/infra/migration-test.tfvars
make init-ssh ENV=migration-test PRIVATE=1
```

The private tfvars files should reference the token file path, not the token value:

```hcl
proxmox_api_token_file = "~/.config/platform-infrastructure/infra/proxmox.token"
```

The scaffolded examples use `proxmox_insecure = false` so Proxmox API TLS verification is enabled by default. Prefer trusting the Proxmox API certificate from the operator workstation and CI runners. Use `proxmox_insecure = true` only as an explicit private/local override for a known self-signed setup after accepting the MITM and token exposure risk.

### Trust the Proxmox API Certificate

Proxmox stores the cluster CA certificate at `/etc/pve/pve-root-ca.pem`. The
certificate is public trust material, not a private key, but it is specific to
the environment and should remain outside Git. Proxmox does not expose this file
through its API or web interface, so retrieve it through a trusted,
authenticated channel such as SSH or the node console.

For example, copy it over SSH into the existing local infrastructure config
directory:

```bash
install -d -m 0700 ~/.config/platform-infrastructure/infra
scp <proxmox-user>@<proxmox-host>:/etc/pve/pve-root-ca.pem \
  ~/.config/platform-infrastructure/infra/proxmox-ca.pem
chmod 0600 ~/.config/platform-infrastructure/infra/proxmox-ca.pem
```

Use the least-privileged account that can read the CA file. Some Proxmox hosts
restrict it to privileged accounts, in which case follow the host's approved
administrative access policy rather than broadening its permissions.

Verify the SSH host key through a trusted source before accepting it, especially
on the first connection. Inspect the copied certificate and test it against the
API endpoint before installing it into the workstation or CI runner trust store:

```bash
openssl x509 \
  -in ~/.config/platform-infrastructure/infra/proxmox-ca.pem \
  -noout -subject -issuer -fingerprint -sha256
curl --cacert ~/.config/platform-infrastructure/infra/proxmox-ca.pem \
  --fail --silent --show-error --output /dev/null \
  https://<proxmox-host>:8006/
```

The endpoint hostname or IP must also appear in the Proxmox API certificate. To
scope the CA to the private OpenTofu workflow instead of changing system trust,
add these exports to the matching private `*.tofu.env` file:

```bash
export PROXMOX_CA_FILE="$HOME/.config/platform-infrastructure/infra/proxmox-ca.pem"
export SSL_CERT_FILE="$PROXMOX_CA_FILE"
```

`PROXMOX_CA_FILE` is the environment-specific input path. Assign it explicitly
in each environment file so switching environments cannot retain another
environment's CA. On supported non-macOS Unix systems, `SSL_CERT_FILE` is a Go
trust setting inherited by OpenTofu and the `bpg/proxmox` provider. Source the
private environment file before `tofu init`, `plan`, or `apply`, and keep
`proxmox_insecure = false`.

On Unix systems other than macOS, setting `SSL_CERT_FILE` changes the default CA
bundle file considered by Go processes. Default certificate directories are
still considered, but CI images and other runtimes can differ. Use the combined
bundle described in [CI/CD](ci.md#gitlab-proxmox-ca-trust) when the same process
also needs reliable public CA trust. On macOS, install the verified CA in the
applicable system or login keychain instead of relying on `SSL_CERT_FILE`.

Alternatively, install the verified CA using the operating system's trust-store
procedure. For example, on Debian or Ubuntu:

```bash
sudo install -m 0644 \
  ~/.config/platform-infrastructure/infra/proxmox-ca.pem \
  /usr/local/share/ca-certificates/proxmox-ca.crt
sudo update-ca-certificates
```

System trust does not require `SSL_CERT_FILE`. Do not commit the
environment-specific CA to this public repository with either approach.

Expected private layout:

```text
../platform-private/infra/
  homelab.tfvars
  dev.tfvars
  config-test.tfvars
  snapshot-test.tfvars
  migration-test.tfvars
  homelab.tofu.env
  dev.tofu.env
  config-test.tofu.env
  snapshot-test.tofu.env
  migration-test.tofu.env
```

The `.tofu.env` files contain no secrets. Homelab and dev set
`TF_CLI_ARGS_plan`, `TF_CLI_ARGS_apply`, and `TF_CLI_ARGS_destroy`. Config-test,
snapshot-test, and migration-test intentionally unset apply arguments so
applying requires a reviewed saved plan.

`make init-ssh` reads the selected environment's `vms` map and generates one local cloud-init SSH keypair per VM with `platform-ssh-init`. The default key path pattern is:

```text
~/.ssh/platform-infra-<env>-<vm-key>-cloud-init_ed25519
```

OpenTofu reads the matching `.pub` file for each VM during planning and injects it through cloud-init. The private key path is exposed in `ansible_inventory_map` for `platform-config` handoff.

These generated keys authenticate to guest VMs; they are not SSH client
identities accepted by the Proxmox host. `platform-proxmox-vm-snapshot
--identity-file` instead requires an SSH
identity accepted by the Proxmox host, such as the public example convention
`~/.ssh/platform-template-builder_ed25519`. `platform-infra` does not generate
that operator identity through `make init-ssh`; create or select it separately with
`platform-ssh-init`, `ssh-agent`, or SSH configuration.

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

After apply, use [Manual VM Verification](vm-manual-checks.md) to check the live
VM shape, initial SSH access, network intent, disk visibility, and guest-agent
reporting before handoff to `platform-config`.

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

## Config Test Workflow

Use this root only for explicitly approved, isolated `platform-config`
acceptance. Run setup helpers from the repository root:

```bash
make deps
make env ENV=config-test PRIVATE=1
make init-ssh ENV=config-test PRIVATE=1
make validate ENV=config-test
```

The specialized
[`proxmox-config-test-environment.md`](./proxmox-config-test-environment.md)
runbook is authoritative for collision checks, exclusive-use reservation,
saved-plan approval, provisioning, handoff, and destruction. Do not enroll the
VM in normal dev, service, or storage inventories.

The fixture is normally absent with valid empty state and an inactive private
inventory. Create it only for a named campaign. A `platform-config` coder may
use it only after the current VM incarnation has passed fresh host-key,
readiness, and stable-disk handoff gates. Destroy it and retire those bindings
when the campaign releases it.

## Snapshot Test Workflow

Use this root only for explicitly approved live acceptance of
`platform-proxmox-vm-snapshot`. Run setup helpers from the repository root:

```bash
make deps
make env ENV=snapshot-test PRIVATE=1
make init-ssh ENV=snapshot-test PRIVATE=1
make validate ENV=snapshot-test
```

The specialized
[`proxmox-snapshot-test-environment.md`](./proxmox-snapshot-test-environment.md)
runbook is authoritative for preflight, saved-plan approval, provisioning,
verification, and destruction. Do not use the general apply or destroy examples
below for this stricter root. Snapshot operations follow the tool-owned live
acceptance runbook; do not enroll the disposable VMs in platform services.

## Migration Test Workflow

Use this root only to provision clean Rocky Linux 10.0 and 10.1 baselines for an
explicitly approved, consumer-owned migration campaign:

```bash
make deps
make env ENV=migration-test PRIVATE=1
make init-ssh ENV=migration-test PRIVATE=1
make validate ENV=migration-test
```

The specialized
[`proxmox-migration-test-environment.md`](./proxmox-migration-test-environment.md)
runbook is authoritative for template and collision preflight, saved-plan
approval, exact-version handoff, consumer reservation, and destruction. This
repository does not configure or mutate either guest. Do not enroll the VMs in
normal platform services, and recreate both baselines for each clean campaign.

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

```bash
cd environments/config-test
source "../../../platform-private/infra/config-test.tofu.env"
```

```bash
cd environments/snapshot-test
source "../../../platform-private/infra/snapshot-test.tofu.env"
```

```bash
cd environments/migration-test
source "../../../platform-private/infra/migration-test.tofu.env"
```

Never cross-use tfvars or state between roots. Each root has an independent VM
set, and selecting another root's tfvars can produce destructive plans.

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

Use `environments/dev` and `dev.tofu.env` for dev destroys. Config-test,
snapshot-test, and migration-test use the stricter saved-plan destruction
procedures in their respective
[`config-test`](./proxmox-config-test-environment.md),
[`snapshot-test`](./proxmox-snapshot-test-environment.md), and
[`migration-test`](./proxmox-migration-test-environment.md) runbooks, only after
the owning acceptance workflow releases the fixtures and explicit review
succeeds.

Prefer this over deleting VMs manually in Proxmox. Manual deletion leaves OpenTofu state stale and requires state repair.

## Validation-Only Workflow

Use this before review or commit. It does not contact Proxmox and does not need private tfvars:

```bash
make verify TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=dev TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=config-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=snapshot-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=migration-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

Equivalent local checks with the default install path are:

```bash
make verify
make verify ENV=dev
make verify ENV=config-test
make verify ENV=snapshot-test
make verify ENV=migration-test
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
make verify ENV=config-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=snapshot-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=migration-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
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

The full downstream operator sequence is documented in `../platform-config/docs/operator-runbook.md`. That runbook covers Ansible environment files, Make targets, service order, smoke checks, and secret file locations.

The first structured handoff output is:

```bash
~/.local/bin/tofu output ansible_inventory_map
```

When DHCP is used, actual leased IP outputs require a working `qemu-guest-agent` in the template.

## Reserve Service Addresses

Reserve service addresses before handing provisioned VMs to `platform-config`.
Record reservations by purpose in the environment's private network inventory or
lifecycle record, for example:

| Reservation | Environment-specific address |
| --- | --- |
| OpenBao service VIP | `<openbao-vip>` |
| Monitoring service VIP | `<monitoring-vip>` |

Do not publish private environment addresses in this repository. If the network
uses DHCP, keep reserved addresses outside its dynamic pool or add authoritative
reservations. If the network has no DHCP service, record that fact with the
address reservation. In either case, check the authoritative network inventory,
DNS, and live address use before approving the addresses.

Reserved service addresses must not also appear as VM cloud-init addresses.
`platform-infra` documents the reservation and provisions node addresses; actual
VIP interfaces, failover, DNS records, and service configuration belong in
`platform-config` or the environment's network-management workflow.

## Boundary

Do not add template-building logic, Ansible playbooks, Kubernetes scripts, Kubernetes manifests, certificate authority files, service certificates, `fstab`, NFS mounts, partitioning/formatting/mounting of attached disks, Docker/Podman setup, systemd services, backup scripts inside VMs, or application deployment code to this repository.
