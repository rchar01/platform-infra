# Snapshot Test Environment

This OpenTofu root manages two disposable VMs for live acceptance testing of
`platform-proxmox-vm-snapshot`. It has independent state and must never share
tfvars or state with another environment root.

The root owns only VM existence, virtual hardware, network intent, initial
cloud-init access, and handoff outputs. Snapshot operations belong to
`platform-tools`; temporary guest disk preparation belongs to the private or
tool-owned acceptance fixture.

`make init-ssh ENV=snapshot-test PRIVATE=1` generates per-VM guest cloud-init
keys. Those keys are not used by `platform-proxmox-vm-snapshot`; the snapshot
helper's `--identity-file` must select a separate SSH key accepted by the
Proxmox host.

## Private Config

The normal private workflow uses:

- `../../../platform-private/infra/snapshot-test.tfvars`.
- `../../../platform-private/infra/snapshot-test.tofu.env`.

Source `snapshot-test.tofu.env` from this root before native OpenTofu
operations. Apply only a reviewed saved plan, and destroy the two VMs after the
acceptance run.

Run `make init-ssh ENV=snapshot-test PRIVATE=1` from the repository root after
editing the private tfvars. It generates one dedicated keypair per disposable
VM under `~/.ssh`.

See `../../docs/proxmox-snapshot-test-environment.md` for approval gates,
lifecycle entry and exit conditions, and destruction requirements.
