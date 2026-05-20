# Changelog

All notable changes to `platform-infra` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
