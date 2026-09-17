# Requirements

`platform-infra` assumes a Proxmox template already exists. Use `platform-template-builder` to create and maintain templates before using this repository.

For exact setup and run commands, use `workflow.md`.

## Local Workstation

Required local tools:

- Git.
- Make.
- SSH client.
- Text editor.
- OpenTofu `1.11.7` or newer.

The repository can install the pinned OpenTofu version with `make deps`. It installs to `~/.local/bin/tofu` by default and does not require `sudo` or a system package manager.

Use `TOFU_INSTALL_DIR` to choose a different binary directory. CI commonly keeps tooling inside the checkout with `TOFU_INSTALL_DIR="$PWD/.tools/bin"`.

Recommended shared platform tools:

- `platform-config-init` from `platform-tools` for provisioning the protected local outside-Git namespace; concrete files are created by their owning helper, project, or explicit workflow.
- `platform-proxmox-token-init` from `platform-tools` for Proxmox API user/token bootstrap over SSH from the operator workstation.
- `platform-ssh-init` from `platform-tools` for per-VM cloud-init SSH keypair creation.

Recommended local inputs:

- Public SSH key for cloud-init injection.
- Access to the Proxmox UI for first-run verification.
- Access to the sibling private config repo at `../platform-private` for the normal private workflow.

## Proxmox

Required Proxmox resources:

- Existing VM template ID.
- API token for OpenTofu automation.
- A Proxmox API certificate trusted by the operator workstation and CI runners, or an explicit private decision to use `proxmox_insecure = true` only for local fallback testing.
- Apply-capable Proxmox identity, with a temporary bootstrap role or least-privilege role that can clone and manage the intended VMs.
- Target node name.
- Network bridge, usually `vmbr0`.
- Datastore for cloned VM disks.
- Datastore for cloud-init disks.

Proxmox API token bootstrap additionally needs SSH access to the Proxmox host as a user that can run `pveum`, the `/etc/pve` Proxmox marker, and `bash`. Automatic token-file writing with `platform-proxmox-token-init --write-token-file` also needs `jq` on the Proxmox host.

The Proxmox API token can be provided directly with `proxmox_api_token`, but local runs should prefer `proxmox_api_token_file = "~/.config/platform-infrastructure/infra/proxmox.token"`. Provision the local config directory with `platform-config-init` and keep the token file outside Git with `0600` permissions.

Example tfvars keep `proxmox_insecure = false` so TLS verification is enabled by default. If a private environment still uses a self-signed or otherwise untrusted Proxmox certificate, follow [Trust the Proxmox API Certificate](workflow.md#trust-the-proxmox-api-certificate) or use a valid certificate. Set `proxmox_insecure = true` only as an explicit private/local override after accepting the token exposure risk on that network path.

Private repository configs should not contain the token value. They may contain normal private configuration such as the matching `*.tfvars` and `*.tofu.env` files for each environment root.

See `proxmox-api-token.md` for Proxmox user, token, and ACL setup guidance for the first apply.

## OpenTofu Roots

The maintained OpenTofu roots are independent:

- `environments/homelab` uses homelab state and `homelab.tfvars`.
- `environments/dev` uses dev state and `dev.tfvars`.
- `environments/config-test` uses disposable acceptance state and `config-test.tfvars`.
- `environments/snapshot-test` uses disposable acceptance state and `snapshot-test.tfvars`.
- `environments/migration-test` uses disposable acceptance state and `migration-test.tfvars`.

Use native OpenTofu for `plan`, `apply`, and `destroy` from the selected environment root. Use Make targets from the repository root for setup, formatting, and validation helpers.

Proxmox cloud-init automatic package upgrades remain disabled. Templates must
already provide the intended guest release; subsequent package updates belong to
an explicitly reviewed `platform-config` workflow.

Live snapshot acceptance additionally requires a single-node Proxmox VE 9 host with `bash`, `pvesh`, `jq`, and `qm`, plus enough snapshot-capable storage for two disposable clones, their additional disks, and optional saved memory state. See `proxmox-snapshot-test-environment.md`.

Live config-test acceptance additionally requires the validated Rocky Linux 10.1
template, capacity for one disposable clone and its test disk, trusted console
access for SSH host-key authentication, and an isolated `platform-config`
inventory. See `proxmox-config-test-environment.md`.

Live migration-test acceptance additionally requires validated Rocky Linux 10.0
and 10.1 templates, capacity for two full clones, trusted console access for SSH
host-key authentication, and a consumer that accepts the clean-baseline handoff.
See `proxmox-migration-test-environment.md`.

## CI Requirements

Secret-free CI validation needs:

- Git.
- Make.
- Network access to the OpenTofu and provider registries.
- The repo-pinned OpenTofu installer.

CI plans that contact Proxmox additionally need:

- Access to the target Proxmox API endpoint.
- `TF_VAR_proxmox_api_token` injected from the CI secret store.
- Matching private tfvars for the selected environment.
- Valid per-VM SSH public key input for cloud-init.
- Access to the selected environment state.

CI applies additionally require remote state with locking, protected deployment jobs, and manual approval. Do not run apply from an ephemeral runner using local state.

## Guest Agent

The VM module exposes `agent_enabled`, defaulting to `true`, because platform templates should include and start `qemu-guest-agent`.

`platform-template-builder` is responsible for installing and enabling the agent inside the template. `platform-infra` only tells Proxmox whether to expect the agent.

If the current template does not have a working guest agent, set `agent_enabled = false` in the selected environment tfvars before applying.

Without a working guest agent, OpenTofu can still provision the VM, but guest-reported IP outputs may be empty.

## Proxmox Disk Performance

For Linux VMs on Proxmox, especially with ZFS-backed storage, the practical target shape is:

- Host storage backed by a ZFS pool when that is the selected Proxmox storage design.
- VM disks on zvol or raw block storage rather than qcow2 files on ZFS.
- SCSI disk interfaces such as `scsi0` and `scsi1` with the `virtio-scsi-single` controller.
- IO thread enabled for VM disks.
- Discard/TRIM enabled so space reclamation can pass through to the underlying storage.
- Disk cache set to `none` by default; use `writeback` only when the durability and power-loss tradeoffs are deliberate.
- Guest filesystems such as XFS or ext4 for typical Linux workloads.

Repository boundary still applies. `platform-infra` may own virtual disk shape, datastore selection, controller, cache, IO thread, and discard settings. `platform-template-builder` owns template image preparation. `platform-config` owns guest partitioning, formatting, filesystems, LVM, mounts, and `fstab`.

The module defaults to `scsi_hardware = "virtio-scsi-single"`, disk `iothread = true`, `discard = "on"`, `cache = "none"`, and `file_format = "raw"`. Environment roots expose defaults and per-VM overrides for those settings; additional disks can override cache, discard, file format, IO thread, and an optional guest-visible serial per disk.

QEMU guest agent filesystem trim integration stays disabled by default with `default_agent_trim = false`. Enable it only when the template reliably installs and starts `qemu-guest-agent`, the guest filesystem stack supports fstrim safely, and the operator wants Proxmox-triggered guest fstrim in addition to disk-level discard. Inspect `tofu plan` carefully before applying these settings to existing VMs because disk/controller changes can require shutdowns or affect cloned disk attributes.

## Memory Ballooning

The VM module treats `memory_mb` as the Proxmox maximum memory value. Set optional `memory_floating_mb` per VM to configure the Proxmox ballooned minimum memory value.

Use this only for VM memory shape. Guest balloon driver support belongs in the template or guest OS and is outside this repository.

## Repository Boundary

`platform-infra` owns VM existence and VM shape, not inside-OS configuration.

In this repository, cloud-init is limited to initial identity and access:

- Hostname.
- Initial user.
- Per-VM SSH public key injection.
- DHCP or static IP intent.
- DNS server and search-domain intent.
- Proxmox-side guest agent flag.

Do not use cloud-init here for complex OS configuration.

## Template Boundary

Do not add these tasks to this repository:

- Cloud image downloads.
- `qm importdisk`.
- Template conversion.
- Package installation.
- Cloud image cleanup.
- Guest OS hardening.

Those belong in `platform-template-builder` or later configuration repositories.

## Inside-OS Configuration Boundary

Do not add these tasks to this repository:

- `fstab`.
- NFS mounts.
- Partitioning, formatting, or mounting attached virtual disks.
- Users beyond the initial cloud-init user.
- Firewall rules inside the guest.
- Docker or Podman setup.
- Application configuration.
- Systemd services.
- Backup scripts inside VMs.
- Certificates inside services.
- Kubernetes manifests.

Those belong in `platform-config`, `platform-k8s-bastion`, or service-specific repositories.
