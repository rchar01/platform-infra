# Config Test Environment

This OpenTofu root defines one on-demand disposable Rocky Linux VM for isolated
`platform-config` acceptance. Its expected idle state is valid empty state and
no live VM. It has independent state and must never share tfvars or state with
another environment root.

The root owns only VM existence, virtual hardware, network intent, initial
cloud-init access, and handoff outputs. Packages, partitioning, LVM,
filesystems, mounts, reboot orchestration, and acceptance assertions belong to
`platform-config` and its test-specific operator workflow.

## Private Config

The normal private workflow uses:

- `../../../platform-private/infra/config-test.tfvars`.
- `../../../platform-private/infra/config-test.tofu.env`.

Run `make init-ssh ENV=config-test PRIVATE=1` from the repository root after
editing the private tfvars. Source `config-test.tofu.env` from this root before
native OpenTofu operations. Apply and destroy only reviewed saved plans.

Retain the private inputs, SSH identity, and empty state between campaigns. A
recreated VM requires fresh collision checks, host-key authentication, guest
readiness validation, and stable-disk discovery before private inventory
activation; a previous handoff never authorizes a new incarnation.

See `../../docs/proxmox-config-test-environment.md` for collision checks,
exclusive-use rules, lifecycle gates, and the `platform-config` handoff.
