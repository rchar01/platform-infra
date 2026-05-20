# News

This file gives a short, release-oriented view of what changed between versions.

## Unreleased

No unreleased changes.

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
