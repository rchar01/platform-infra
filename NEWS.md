# News

This file gives a short, release-oriented view of what changed between versions.

## Unreleased

README workflow and Proxmox disk-performance guidance.

Highlights:

- Added practical Proxmox disk-performance guidance for Linux VMs and documented which parts belong to infra versus guest configuration.
- Updated the README header with a centered 256px project logo and separator.
- Clarified when to use root Make helpers and when to run native `tofu` from an environment root.

## v1.3.1 - 2026-05-26

Public representative VM examples and SSH key path fix.

Highlights:

- Expanded dev examples to cover the representative platform component classes.
- Added a homelab GitLab example with homelab-specific tags.
- Fixed `make init-ssh` so the default SSH key directory resolves to `$HOME/.ssh` under quoted shell execution.

## v1.3.0 - 2026-05-25

Public example sanitization.

Highlights:

- Replaced environment-shaped public examples with neutral names and placeholder token identities.
- Added a publication checklist for keeping future public examples free of real environment values.

## v1.2.2 - 2026-05-22

Documentation and local secret path cleanup.

Highlights:

- `platform-config-init` is now documented as the normal way to create the local outside-Git config directory.
- The documented Proxmox token file moved to `~/.config/platform-infrastructure/infra/proxmox.token`.

## v1.2.1 - 2026-05-21

Maintenance fix for the SSH key initialization workflow.

Highlights:

- `make init-ssh` now defers `HOME` expansion for the default `SSH_KEY_DIR`, avoiding unsafe Make-time interpolation.

## v1.2.0 - 2026-05-20

Security and handoff workflow update.

Highlights:

- `make init-ssh` now creates per-VM cloud-init SSH keys instead of one environment-wide key.
- OpenTofu now exposes per-VM Ansible SSH key paths in `ansible_inventory_map`.
- Example tfvars now keep Proxmox API TLS verification enabled by default.

## v1.1.0 - 2026-05-17

Branding update.

Highlights:

- Added project logo assets.
- Displayed the transparent project logo in the README.

## v1.0.0 - 2026-05-17

Initial public release of `platform-infra`.

Highlights:

- Provisions Proxmox VMs from existing templates with OpenTofu.
- Provides independent `homelab` and `dev` environment roots and state boundaries.
- Supports CPU, memory, memory ballooning, boot disk, additional disk, bridge, datastore, tag, and description settings.
- Keeps cloud-init minimal: hostname, initial user, SSH key, IP addressing, and DNS intent.
- Uses local token files and private tfvars to keep Proxmox credentials and real environment values out of the public repository.
- Includes Make helpers for setup, formatting, validation, and private config scaffolding.
- Produces structured handoff outputs for later `platform-config` inventory generation.
