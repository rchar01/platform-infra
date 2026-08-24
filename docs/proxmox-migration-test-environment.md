# Proxmox Migration-Test Environment

## Purpose

The `environments/migration-test` OpenTofu root provisions two disposable,
clean Rocky Linux baseline VMs for a downstream migration test: one Rocky 10.0
VM and one Rocky 10.1 VM. It has independent state and must never share tfvars
or state with another environment root.

This repository does not perform a migration. It owns VM existence, virtual
hardware, network intent, initial cloud-init access, and handoff outputs. The
consuming repository owns all guest configuration, mutation, migration logic,
and test assertions.

The expected idle state is valid empty OpenTofu state and no live migration-test
VMs. Create both VMs for an approved campaign, retain them while the consumer
owns the handoff, and destroy them after release.

## Disposable VM Specification

| Property | Rocky 10.0 baseline | Rocky 10.1 baseline |
| --- | --- | --- |
| Source | Existing validated Rocky 10.0 template | Existing validated Rocky 10.1 template |
| CPU | 2 cores, `host` CPU type | 2 cores, `host` CPU type |
| Memory | 2048 MiB | 2048 MiB |
| Boot disk | 20 GiB on `scsi0` | 20 GiB on `scsi0` |
| Additional disks | None | None |
| Cloud-init user | `rocky` | `rocky` |
| QEMU guest agent | Enabled | Enabled |
| Data retention | None | None |
| Recovery | Destroy and recreate | Destroy and recreate |

Proxmox cloud-init package upgrades are disabled. At infrastructure handoff,
the first VM must still report Rocky Linux `VERSION_ID=10.0` with persistent DNF
`releasever=10.0`; the second must report `VERSION_ID=10.1` and DNF
`releasever=10.1`.

The root automatically adds `managed-by-tofu` and `migration-test`; each VM adds
`rocky` and `disposable`. Disk defaults use `virtio-scsi-single`, IO threads,
discard `on`, cache `none`, and raw format.

## Persistent Assets

Retain these between campaigns:

- `environments/migration-test/` and its valid empty state.
- `platform-private/infra/migration-test.tfvars`.
- `platform-private/infra/migration-test.tofu.env`.
- The private operator overlay and dated evidence records.
- Dedicated guest cloud-init keypairs outside Git.

State, saved plans, API tokens, private keys, authenticated host keys, and real
infrastructure values are private operational data.

## Prepare Local Configuration

Run setup from the `platform-infra` repository root:

```bash
make deps
make env ENV=migration-test PRIVATE=1
make init-ssh ENV=migration-test PRIVATE=1
make validate ENV=migration-test
```

Review the private tfvars. Require exactly two VMs, explicit and distinct
template VM IDs, the documented VM shape, and no additional disks.

## Preflight

Before every create plan, verify through current Proxmox and network records:

- migration-test OpenTofu state is empty;
- both proposed VM IDs and hostnames are absent;
- both proposed addresses are unassigned;
- no unrelated VM carries the `migration-test` tag;
- both templates exist, are cloneable, and retain compatible `host` CPUs;
- the templates have `ciupgrade=0` and match the expected Rocky versions;
- the bridge and datastores exist and have capacity for two full clones; and
- no active campaign owns the fixture.

Silence from ICMP or ARP alone is not authoritative address allocation evidence.
Use the private operator overlay for the environment-specific checks and stop on
any collision or uncertainty.

## Create A Reviewed Plan

From the isolated root:

```bash
cd environments/migration-test
source "../../../platform-private/infra/migration-test.tofu.env"

test ! -e migration-test.tfplan &&
~/.local/bin/tofu init &&
~/.local/bin/tofu validate &&
~/.local/bin/tofu plan -out=migration-test.tfplan &&
~/.local/bin/tofu show -no-color migration-test.tfplan &&
sha256sum migration-test.tfplan
```

The reviewed plan must contain exactly two creates and no update, replacement,
or destroy. Confirm that each VM clones the intended exact-minor template and
has only the documented hardware, tags, and cloud-init intent. Record the plan
checksum and obtain explicit approval for that artifact.

Repeat collision checks immediately before apply, then apply only the approved
saved plan:

```bash
approved_plan_sha256="<approved-create-plan-sha256>"

test "$(sha256sum migration-test.tfplan | cut -d ' ' -f 1)" = \
  "$approved_plan_sha256" &&
TF_CLI_ARGS_apply= ~/.local/bin/tofu apply migration-test.tfplan
```

The private environment intentionally unsets `TF_CLI_ARGS_apply`; an unsaved
apply is not an accepted lifecycle path.

## Verify Infrastructure Handoff

Inspect the structured outputs without copying private values into public logs:

```bash
~/.local/bin/tofu output vm_ids
~/.local/bin/tofu output vm_ipv4_config
~/.local/bin/tofu output ansible_inventory_map
~/.local/bin/tofu plan -detailed-exitcode
```

Require:

- exactly two expected VM ID and hostname bindings;
- exactly the four documented tags on each VM;
- 2 cores, 2048 MiB memory, `host` CPU, and one 20 GiB boot disk per VM;
- the expected bridge, DNS, and cloud-init network intent;
- successful cloud-init completion and SSH access;
- a responsive QEMU guest agent reporting the expected address;
- Rocky 10.0 and DNF `releasever=10.0` on the 10.0 baseline;
- Rocky 10.1 and DNF `releasever=10.1` on the 10.1 baseline; and
- a no-change refreshed OpenTofu plan.

Authenticate each first SSH host key against a trusted Proxmox console
observation. Do not use `StrictHostKeyChecking=no`, `accept-new`, or an
unauthenticated `ssh-keyscan` result.

## Consumer Handoff

The consuming repository may read `ansible_inventory_map` or equivalent private
bindings to obtain each hostname, address, cloud-init user, SSH identity path,
VM ID, and expected baseline role. Keep real inventory and campaign evidence in
private or consumer-owned files.

During the handoff:

- reserve both VMs to one named campaign;
- record the `platform-infra` revision and current VM identities;
- treat the Rocky 10.0 and 10.1 version checks as immutable handoff evidence;
- allow the consumer to mutate guest state only after accepting the handoff;
- do not change VM hardware, cloud-init inputs, state, or Proxmox ownership
  outside this root; and
- do not enroll either VM in normal platform or service inventories.

Guest changes made by the consumer invalidate the clean-baseline assertion but
do not transfer VM lifecycle ownership. A new clean campaign requires destroy
and recreate, not manual rollback or cleanup.

## Release And Destroy

Destroy only after the consumer explicitly releases both VMs and confirms that
no data must be retained. Generate and inspect a fresh saved destroy plan:

```bash
~/.local/bin/tofu plan -destroy -out=migration-test-destroy.tfplan
~/.local/bin/tofu show -no-color migration-test-destroy.tfplan
sha256sum migration-test-destroy.tfplan
```

Require exactly two destroys and no create, update, or replacement. Record and
approve the exact artifact, revalidate both target identities and tags, then:

```bash
approved_plan_sha256="<approved-destroy-plan-sha256>"

test "$(sha256sum migration-test-destroy.tfplan | cut -d ' ' -f 1)" = \
  "$approved_plan_sha256" &&
TF_CLI_ARGS_apply= ~/.local/bin/tofu apply migration-test-destroy.tfplan
```

Verify empty state and authoritative absence of both VM IDs, names, and the
`migration-test` tag. Remove saved plans and retire host-key, reservation, and
readiness observations for that incarnation. Retain the valid empty state and
configuration for the next campaign.

Do not delete OpenTofu-managed VMs manually in Proxmox except during an approved
break-glass state-repair procedure.
