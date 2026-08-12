# Proxmox Config-Test Environment

## Purpose

The `environments/config-test` OpenTofu root provisions one disposable Rocky
Linux VM for isolated `platform-config` acceptance. It is a general test fixture;
storage is its first campaign, not its permanent exclusive purpose.

This root owns VM existence, shape, network intent, initial cloud-init access,
and handoff outputs. `platform-config` owns packages, partitioning, LVM,
filesystems, mounts, reboot orchestration, and test assertions. Real bindings
belong in `platform-private`.

Do not reuse `snapshot-test`: that two-VM root has a separate snapshot-tool
acceptance contract. Do not add `config-test` to `dev`, RKE2, service, or normal
storage inventories.

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

- the proposed VM ID does not exist;
- the proposed hostname is unused;
- the proposed static address is unassigned;
- the Rocky Linux 10.1 template exists and retains a compatible `host` CPU;
- the selected bridge and datastores exist and have sufficient capacity;
- no active test campaign owns the `config-test` fixture; and
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

```bash
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

## Destroy

After the owning campaign releases the VM, generate a separate saved destroy
plan:

```bash
cd environments/config-test
source "../../../platform-private/infra/config-test.tofu.env"

test ! -e config-test-destroy.tfplan &&
~/.local/bin/tofu plan -destroy -out=config-test-destroy.tfplan &&
~/.local/bin/tofu show -no-color config-test-destroy.tfplan &&
sha256sum config-test-destroy.tfplan
```

Require exactly one destroy and no other action. Obtain explicit approval for
that checksum, then apply only that artifact:

```bash
TF_CLI_ARGS_apply= ~/.local/bin/tofu apply config-test-destroy.tfplan
```

Confirm empty state and no live VM with the private identity or `config-test`
tag. Remove local saved plans only after successful destruction. Never recover
from state disagreement by deleting a live VM manually; reconcile ownership and
state first.
