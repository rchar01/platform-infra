# Proxmox Config-Test Environment

## Purpose

The `environments/config-test` OpenTofu root defines one on-demand disposable
Rocky Linux VM for isolated `platform-config` acceptance. The expected idle
state is empty OpenTofu state and no live VM. Create a fresh VM incarnation for
an explicitly named campaign and destroy it when the handoff is released.
Storage is the first campaign, not the fixture's permanent exclusive purpose.

This root owns VM existence, shape, network intent, initial cloud-init access,
and handoff outputs. `platform-config` owns packages, partitioning, LVM,
filesystems, mounts, reboot orchestration, and test assertions. Real bindings
belong in `platform-private`.

Do not reuse `snapshot-test`: that two-VM root has a separate snapshot-tool
acceptance contract. Do not add `config-test` to `dev`, RKE2, service, or normal
storage inventories.

The root, private inputs, SSH identity, and valid empty state are reusable. A
live VM, authenticated host key, stable guest-device path, reservation, and
readiness observations are bound to one incarnation and expire at destruction.
Reusing a VM ID, hostname, address, serial, or by-id string does not carry those
acceptance results into a recreated VM.

## Disposable VM Specification

| Property | Value |
| --- | --- |
| VM count | One |
| Operating system | Rocky Linux 10.1 from the approved existing template |
| CPU | 2 cores, `host` CPU type |
| Memory | 2048 MiB |
| Boot disk | 25 GiB on `scsi0` |
| Test disk | 32 GiB on `scsi1` |
| Test disk serial | Explicit 1-20 character ASCII identifier |
| Cloud-init user | `rocky` |
| QEMU guest agent | Enabled |
| Data retention | None |
| Recovery | Destroy and recreate |

Proxmox cloud-init package upgrades are disabled. The guest must retain the
template's Rocky Linux 10.1 release through first boot.

The root automatically adds `managed-by-tofu` and `config-test`; the VM adds
`rocky` and `disposable`. Disk defaults use `virtio-scsi-single`, IO threads,
discard `on`, cache `none`, and raw format.

An explicit serial helps produce a stable guest identity, but it is not proof of
the final udev path. Never authorize destructive work against `/dev/sdX` or
infer a path from `scsi1` alone.

## Files And Boundaries

- Public root: `environments/config-test/`
- Private inputs: `platform-private/infra/config-test.tfvars`
- Private shell environment: `platform-private/infra/config-test.tofu.env`
- Private operator bindings: `platform-private/infra/config-test/operator-overlay.md`
- Private Ansible inventory: `platform-private/config/inventories/config-test/`
- Platform-config handoff: `platform-plans/config/plans/config-test-storage-volume-handoff.md`

API tokens and SSH private keys remain outside Git. State, saved plans, host-key
fingerprints, and live device observations are private operational data.

## Prepare Local Configuration

Run setup from the `platform-infra` repository root:

```bash
make deps
make env ENV=config-test PRIVATE=1
make init-ssh ENV=config-test PRIVATE=1
make validate ENV=config-test
```

Review the private tfvars before planning. Confirm that it declares exactly one
VM and one additional 32 GiB `scsi1` disk with the approved serial.

## Preflight

Before every create plan, verify through authoritative Proxmox and network
records that:

- the config-test OpenTofu state is empty;
- the proposed VM ID does not exist;
- the proposed hostname is unused;
- the proposed static address is unassigned;
- the Rocky Linux 10.1 template exists and retains a compatible `host` CPU;
- the selected bridge and datastores exist and have sufficient capacity;
- no active test campaign owns the `config-test` fixture; and
- the private config-test inventory has no active host and no accepted stable
  device from an earlier incarnation; and
- no unrelated VM carries the `config-test` tag.

Silence from ICMP alone does not prove that an address is free. Use the private
operator overlay for exact bindings and approved live checks. Stop on any
collision or uncertainty.

## Provision

From the isolated root:

```bash
cd environments/config-test
source "../../../platform-private/infra/config-test.tofu.env"

test ! -e config-test.tfplan &&
~/.local/bin/tofu init &&
~/.local/bin/tofu validate &&
~/.local/bin/tofu plan -out=config-test.tfplan &&
~/.local/bin/tofu show -no-color config-test.tfplan &&
sha256sum config-test.tfplan
```

The reviewed plan must contain exactly one create and no update, replacement,
or destroy. Record the checksum and obtain explicit approval for that exact
artifact. Then apply only the saved plan:

Immediately before applying, use the private operator overlay to repeat
empty-state, live VM/name/tag absence, and same-subnet address checks. Continue
only if all checks succeed.

```bash
approved_plan_sha256="<approved-create-plan-sha256>"

test "$(sha256sum config-test.tfplan | cut -d ' ' -f 1)" = \
  "$approved_plan_sha256" &&
TF_CLI_ARGS_apply= ~/.local/bin/tofu apply config-test.tfplan
```

The private environment intentionally unsets `TF_CLI_ARGS_apply`; an unsaved
apply is not the accepted lifecycle path.

## Verify Infrastructure Handoff

Inspect the structured handoff without copying private output into a public log:

```bash
~/.local/bin/tofu output ansible_inventory_map
~/.local/bin/tofu plan -detailed-exitcode
```

Require:

- exactly one expected VM ID and hostname;
- the complete four-tag set;
- 2 cores, 2048 MiB memory, and `host` CPU type;
- 25 GiB `scsi0` and 32 GiB `scsi1` disks;
- the approved serial on `scsi1`;
- the expected bridge and cloud-init network intent;
- a responsive QEMU guest agent; and
- a no-change refreshed OpenTofu plan.

## Authenticate And Connect

Obtain the address, user, and identity path from `ansible_inventory_map`. Before
accepting the first SSH host key, compare its fingerprint with the guest's
ED25519 host-key fingerprint observed through the trusted Proxmox console.

The following values are placeholders:

```bash
vm_host="<private-address>"
vm_user="<cloud-init-user>"
vm_identity="$HOME/.ssh/<private-config-test-key>"
vm_known_hosts="$HOME/.ssh/known_hosts"

test -r "$vm_identity" &&
ssh -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=ask \
  -o UserKnownHostsFile="$vm_known_hosts" \
  -i "$vm_identity" \
  "${vm_user}@${vm_host}"
```

Do not use `StrictHostKeyChecking=no`, `accept-new`, or an unverified
`ssh-keyscan` result. For a recreated VM, remove a stale entry only after the
new fingerprint has been independently authenticated.

## Verify Guest Readiness

Run read-only guest checks before handing the VM to a test campaign:

```bash
cat /etc/rocky-release
hostnamectl --static
cloud-init status --long
sudo -n true
systemctl is-active qemu-guest-agent
lsblk -o NAME,SIZE,TYPE,SERIAL,FSTYPE,MOUNTPOINTS
test_disk="/dev/<reviewed-kernel-name>"
find -L /dev/disk/by-id /dev/disk/by-path -samefile "$test_disk"
```

Require Rocky Linux 10.1, the approved hostname, passwordless sudo, an active
guest agent, and one separate 32 GiB non-root disk carrying the approved serial.
Replace `<reviewed-kernel-name>` only after identifying the disk read-only. Record one
stable `/dev/disk/by-id/` or `/dev/disk/by-path/` link in private evidence and
the private inventory. Stop if the path resolves to the root disk, the serial or
size differs, or stable links are absent.

The infrastructure handoff does not authorize partitioning, LVM, formatting,
mounting, cleanup, or reboot. Those operations require the test-specific
`platform-config` workflow and separate approval.

## Reserve A Test Campaign

Before mutation, record a private reservation containing the campaign name,
operator, start time, accepted VM identity, and accepted stable test-disk path.
Only one campaign may own the VM. Destroy and recreate it between incompatible
or destructive campaigns; do not depend on cleanup of unknown prior state.

After authenticating the current VM's host key and recording a newly verified
stable non-root disk path, create immutable handoff and exclusive reservation
evidence. Only then activate the host in the isolated private inventory. A
`platform-config` coder may then run the campaign-specific read-only preflight
and seek any separately required mutation or reboot approval. Never treat a
committed address, old fingerprint, or historical stable path as a current live
handoff.

## Destroy

After the owning campaign or unused infrastructure handoff is released, first:

- confirm no downstream process or operator owns the VM;
- accept total loss of all disposable guest data;
- deactivate the host in the private config-test inventory;
- remove the incarnation-specific `stable_device` from active host variables;
  and
- create a new immutable private release record.

Then generate a separate saved destroy plan:

```bash
cd environments/config-test
source "../../../platform-private/infra/config-test.tofu.env"

test ! -e config-test-destroy.tfplan &&
~/.local/bin/tofu plan -destroy -out=config-test-destroy.tfplan &&
~/.local/bin/tofu show -no-color config-test-destroy.tfplan &&
sha256sum config-test-destroy.tfplan
```

Require exactly one destroy and no other action. Obtain explicit approval for
that checksum. Immediately before applying, use the private operator overlay to
match the live VM's recorded incarnation identifier, expected managed volumes,
identity, tags, and lock state. This prevents an approved plan from destroying a
replacement VM that reused the same VM ID and hostname. Then apply only that
artifact:

```bash
approved_plan_sha256="<approved-destroy-plan-sha256>"

assert_config_test_target &&
test "$(sha256sum config-test-destroy.tfplan | cut -d ' ' -f 1)" = \
  "$approved_plan_sha256" &&
TF_CLI_ARGS_apply= ~/.local/bin/tofu apply config-test-destroy.tfplan
```

Confirm empty state and no live VM with the private identity or `config-test`
tag. Only after both checks pass:

1. Remove stale known-host entries for the retired address and hostname with
   `ssh-keygen -R` against the operator's configured `known_hosts` file.
2. Confirm the private inventory remains inactive and has no `stable_device`.
3. Record apply results, empty state, live absence, trust cleanup, and binding
   cleanup in a new immutable private completion record.
4. Remove local saved plan files.

Retain the private tfvars, `.tofu.env`, dedicated SSH identity, and valid empty
state for future recreation. A normal plan from this idle state should propose
exactly one create because the fixture contract remains declared. Never recover
from state disagreement by deleting a live VM manually; reconcile ownership and
state first.

## Recreate For A Future Campaign

1. Name the campaign, responsible coder or operator, and requested test scope.
2. Confirm empty state, inactive private inventory, no reservation, and no
   incarnation-specific `stable_device`.
3. Revalidate VM ID, hostname, address, tag uniqueness, template, bridge, and
   datastore capacity through authoritative sources.
4. Generate a saved plan containing exactly one create, record its SHA-256, and
   obtain explicit approval for that exact artifact.
5. Apply only the approved plan and verify VM shape, Rocky Linux release,
   cloud-init, guest agent, and a no-change refreshed plan.
6. Record the newly generated Proxmox incarnation identifier and complete
   managed disk configurations in immutable private handoff evidence.
7. Authenticate the new SSH host key through a trusted channel; do not inherit
   the retired key.
8. Resolve the serial-identified test disk to a stable non-root guest path and
   record the new observation privately.
9. Complete immutable handoff and exclusive reservation evidence bound to this VM
   incarnation.
10. Activate the isolated private inventory only after that record exists.
11. Hand the VM to the `platform-config` coder. Guest mutation and reboot remain
   governed by that test-specific workflow and its separate approvals.
12. On campaign release, repeat the saved-plan destruction procedure above.
