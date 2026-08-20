# Changelog

All notable changes to `platform-infra` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

No unreleased changes.

## [1.6.0] - 2026-08-20

### Added

- Added an independent one-VM `config-test` OpenTofu root for reusable,
  disposable `platform-config` acceptance.
- Added optional serial identifiers for additional VM disks, including
  conservative validation and structured handoff output.
- Added a config-test lifecycle runbook covering collision checks, reviewed
  saved-plan creation and destruction, strict SSH access, exclusive campaign
  ownership, and stable guest-device verification.
- Defined config-test as an on-demand fixture whose expected idle state is no
  live VM and valid empty state, with per-incarnation trust and disk handoff.
- Added a sanitized manual VM verification runbook for checking OpenTofu
  outputs, SSH access, guest identity and network intent, virtual hardware,
  guest-agent health, Proxmox configuration, and post-apply drift.
- Documented the disposable snapshot-test VM specification and safe procedures
  for provisioning, starting, and connecting to a reviewed test guest.

### Fixed

- Disabled Proxmox cloud-init automatic package upgrades, which could advance a
  clone to a newer OS minor release before `platform-config` handoff.

## [1.5.1] - 2026-07-31

### Changed

- Expanded the fictional dev OpenTofu example from nine to seventeen VMs, with
  complete retained platform roles plus three OpenBao and three monitoring
  nodes.
- Replaced the old singleton Vault and Kubernetes-monitoring examples with
  purpose-specific OpenBao and monitoring nodes.
- Updated fictional VM IDs and RFC 5737 addresses into one coherent sequence.

## [1.5.0] - 2026-07-31

### Added

- Added a workstation workflow for retrieving the Proxmox cluster CA through an authenticated channel, inspecting its identity, and validating the API endpoint before token use.
- Added scoped non-macOS Unix, system trust, and macOS keychain guidance for keeping Proxmox API TLS verification enabled.
- Added GitLab CI guidance for protected environment-scoped CA file variables and temporary combined CA bundles.
- Added private service-address reservation guidance with public OpenBao and monitoring VIP placeholders.

### Changed

- Updated token troubleshooting to authenticate only after trusted TLS is established and to support scoped CA files or inherited system trust.
- Clarified that real service addresses belong in private network inventory or lifecycle records and must not also be assigned through VM cloud-init.
- Clarified that VIP interfaces, failover, DNS records, and service configuration remain downstream configuration responsibilities.

## [1.4.0] - 2026-07-26

### Added

- Added an independent two-VM `snapshot-test` root for manual live acceptance of `platform-proxmox-vm-snapshot`.
- Added a documented saved-plan workflow and safety gates for creating and destroying disposable snapshot-test VMs.
- Added explicit Proxmox disk performance defaults for VirtIO SCSI single, disk IO threads, discard/TRIM, cache mode, and raw disk format, with root, VM, and additional-disk override support.
- Documented Proxmox disk-performance guidance for Linux VMs, including the boundary between infra-owned virtual disk settings and guest-owned filesystem configuration.

### Changed

- Replaced the completed snapshot-test implementation checklist with a reusable provisioning, verification, live-acceptance entry, destruction, and recovery runbook.
- Environment roots now add `managed-by-tofu` and their environment name automatically; per-VM tags are role-specific.
- Clarified the infra initialization workflow, including `make deps` OpenTofu version and install-directory overrides.
- Kept QEMU guest agent fstrim integration disabled by default and documented when to enable it deliberately.
- Reworded public documentation and agent guidance so the included environment roots are presented as examples rather than product capability limits.
- Reworked the README header with a centered 256px project logo and separator.
- Clarified in the README when to use repository-root Make helper targets versus native `tofu` commands from environment roots.
- Existing environments can plan Proxmox tag, SCSI controller, and disk-attribute updates after upgrading; review plans before applying because some disk or controller changes may require VM shutdown.

## [1.3.1] - 2026-05-26

### Added

- Expanded dev VM examples to cover bastion, registry, registry runner, vault, monitoring, Kubernetes node, Kubernetes runner, and external load balancer patterns.
- Added a homelab GitLab VM example with homelab-specific tags.

### Fixed

- Fixed the `make init-ssh` default SSH key directory so quoted shell execution resolves to `$HOME/.ssh` instead of a literal `~/.ssh` path.

## [1.3.0] - 2026-05-25

### Changed

- Public examples use neutral hostnames, DNS search domains, VM IDs, template IDs, and placeholder Proxmox token identities.
- Added a public repository publication checklist for future documentation and example updates.

## [1.2.2] - 2026-05-22

### Changed

- Documented `platform-config-init` from `platform-tools` as the normal way to create the local outside-Git `~/.config/platform-infrastructure/` directory, with manual directory creation kept as fallback guidance.
- Moved the documented local Proxmox token path under the `infra/` namespace at `~/.config/platform-infrastructure/infra/proxmox.token`.

## [1.2.1] - 2026-05-21

### Fixed

- Avoided Make-time `HOME` expansion in the `init-ssh` SSH key directory default.

## [1.2.0] - 2026-05-20

### Changed

- `make init-ssh` now generates one cloud-init SSH keypair per VM from the selected environment `vms` map.
- OpenTofu now injects per-VM cloud-init SSH public keys by default and exposes matching private key paths in `ansible_inventory_map`.
- Removed env-level cloud-init SSH config scaffolding from the Make workflow.
- Example tfvars now keep Proxmox API TLS verification enabled by default.

## [1.1.0] - 2026-05-17

### Added

- Project logo assets under `assets/brand`.
- Transparent project logo in the README.

## [1.0.0] - 2026-05-17

### Added

- Initial public OpenTofu implementation for Proxmox VM provisioning.
- Independent `homelab` and `dev` environment roots.
- Reusable Proxmox VM module cloned from existing templates.
- VM shape inputs for CPU, maximum memory, ballooned memory, boot disk, additional disks, bridge, datastore, tags, and descriptions.
- Minimal cloud-init inputs for hostname, initial user, SSH key, IPv4 mode/address, gateway, DNS servers, and DNS search domain.
- Token-file based local Proxmox authentication and CI token injection guidance.
- Private config workflow using sibling `platform-private` tfvars and `.tofu.env` files.
- Make targets and scripts for installing OpenTofu, scaffolding config, initializing cloud-init SSH keys, formatting, and validation.
- Structured outputs for VM names, IDs, configured IPs, reported guest-agent IPs, and `platform-config` inventory handoff.
- Documentation for workflow, requirements, state, CI, token setup, troubleshooting, naming conventions, and repository boundaries.
