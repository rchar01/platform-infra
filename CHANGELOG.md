# Changelog

All notable changes to `platform-infra` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Documented Proxmox disk-performance guidance for Linux VMs, including the boundary between infra-owned virtual disk settings and guest-owned filesystem configuration.

### Changed

- Reworked the README header with a centered 256px project logo and separator.
- Clarified in the README when to use repository-root Make helper targets versus native `tofu` commands from environment roots.

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
