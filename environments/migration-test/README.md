# Migration Test Environment

This OpenTofu root manages exactly two disposable clean baseline VMs for
migration testing. It has independent state and must never share tfvars or
state with another environment root.

This repository owns only VM existence, virtual hardware shape, network
intent, minimal cloud-init access, and handoff outputs. Another repository
owns guest configuration and the migration tests.

## Private Config

The normal private workflow uses:

- `../../../platform-private/infra/migration-test.tfvars`.
- `../../../platform-private/infra/migration-test.tofu.env`.

Source `migration-test.tofu.env` from this root before native OpenTofu
operations. Apply only a reviewed saved plan. Destroy both VMs after the
consumer releases the handoff.

Run `make init-ssh ENV=migration-test PRIVATE=1` from the repository root after
editing the private tfvars. It generates one dedicated cloud-init keypair per
disposable VM under `~/.ssh`.

See `../../docs/proxmox-migration-test-environment.md` for lifecycle gates,
handoff requirements, and destruction requirements.
