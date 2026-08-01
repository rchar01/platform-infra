# Manual VM Verification

Use this runbook after an OpenTofu apply to verify that a VM exists with the
reviewed virtual hardware, initial cloud-init access, network intent, and guest
agent behavior. Run the checks from an operator workstation with access to the
selected environment and, where noted, from an authorized Proxmox shell.

This runbook verifies infrastructure handoff readiness. Filesystems, mounts,
packages, users beyond the initial cloud-init user, firewall policy, and service
health belong to `platform-config` or another owning project.

For `snapshot-test`, the stricter
[snapshot-test environment runbook](proxmox-snapshot-test-environment.md)
remains authoritative. This document does not replace its saved-plan,
acceptance, or destruction gates.

## Safety

- Start in the `platform-infra` repository root. Use `tofu -chdir` with the
  selected `environments/<env>` root and that environment's matching tfvars,
  environment file, and state.
- Treat OpenTofu output, plans, VM IDs, addresses, hostnames, and SSH host keys as
  environment-specific operational data. Do not paste them into public issues,
  logs, commits, or documentation.
- Never print or copy a Proxmox API token or SSH private-key content.
- Do not disable SSH host-key checking. Verify an unexpected key through the
  Proxmox console or another trusted channel before changing `known_hosts`.
- Values under `192.0.2.0/24`, names under `example.test`, and identifiers that
  start with `example-` below are documentation values only.
- Stop on an unexpected VM identity, address, disk, route, or OpenTofu action.
  Reconcile the reviewed configuration, state, and live VM before proceeding.

## Prepare the Environment

Run from the `platform-infra` repository root. Replace `<env>` with one
environment root, such as `dev` or `homelab`:

```bash
source "../platform-private/infra/<env>.tofu.env"

~/.local/bin/tofu -chdir="environments/<env>" init
```

Do not cross-use tfvars or state between environment roots.

## Inspect OpenTofu Metadata

Read the VM identity, configured address, guest-agent addresses, and SSH handoff
values from the selected environment's state:

```bash
~/.local/bin/tofu -chdir="environments/<env>" output vm_names
~/.local/bin/tofu -chdir="environments/<env>" output vm_ids
~/.local/bin/tofu -chdir="environments/<env>" output vm_ipv4_config
~/.local/bin/tofu -chdir="environments/<env>" output vm_reported_ipv4_addresses
~/.local/bin/tofu -chdir="environments/<env>" output ansible_inventory_map
```

For the VM being checked, note these fields from `ansible_inventory_map`:

- inventory key
- `hostname`
- `vm_id`
- `ansible_host`
- `ansible_user`
- `ansible_ssh_private_key_file`
- `additional_disks`
- `agent_enabled`

`ansible_host` is `null` for DHCP configuration. In that case, select the
expected address from `vm_reported_ipv4_addresses` and verify it against the
Proxmox UI or another trusted network source before connecting.

Do not save complete output in a tracked file. Record sanitized evidence or an
outside-Git reference when an acceptance record is required.

## Check SSH Access

Set local shell variables from the selected VM's output. The following values
are fictional examples and must not be used as operational defaults:

```bash
vm_key="example-dev-openbao-01"
vm_host="192.0.2.112"
vm_user="rocky"
vm_identity="$HOME/.ssh/platform-infra-dev-example-dev-openbao-01-cloud-init_ed25519"
vm_known_hosts="$HOME/.ssh/known_hosts"
```

The output key path can begin with `~/`. When assigning that path to a quoted
shell variable, spell the prefix as `$HOME/` as shown above; a quoted tilde does
not expand to the home directory.

Confirm that the identity file exists without printing its content:

```bash
test -r "$vm_identity"
```

Select the per-VM identity explicitly. Pin the host-key policy and user
known-hosts file while preserving system-wide trusted and revoked host-key
policy:

```bash
ssh -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=ask \
  -o UserKnownHostsFile="$vm_known_hosts" \
  -i "$vm_identity" \
  "${vm_user}@${vm_host}"
```

On a first connection, compare the presented SSH host-key fingerprint with a
trusted observation from the Proxmox console before accepting it.

If a reviewed VM replacement legitimately changed the host key, inspect the old
entry first:

```bash
ssh-keygen -F "$vm_host" -f "$vm_known_hosts"
```

Only after independently verifying the replacement VM, remove the stale entry
and reconnect:

```bash
ssh-keygen -R "$vm_host" -f "$vm_known_hosts"
ssh -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=ask \
  -o UserKnownHostsFile="$vm_known_hosts" \
  -i "$vm_identity" \
  "${vm_user}@${vm_host}"
```

Do not work around a host-key mismatch with `StrictHostKeyChecking=no`.

## Check the Guest

Run these read-only commands after connecting:

```bash
hostnamectl --static
cloud-init status --long
ip -brief address
ip route
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
nproc
free -h
systemctl is-active qemu-guest-agent
```

Confirm that:

- the hostname matches the selected VM's configured identity
- cloud-init completed without an error
- the intended address and default route are present
- visible disk count and sizes match the reviewed virtual disk shape
- the observed CPU and memory are consistent with the reviewed VM shape
- `qemu-guest-agent` is active when `agent_enabled` is `true`

Disk visibility does not authorize partitioning, formatting, LVM changes, or
mount creation. Those operations belong to `platform-config`.

If the selected template contract requires passwordless administrative access,
check it without opening an interactive root shell:

```bash
sudo -n true
```

## Check Proxmox

In the Proxmox UI, compare the live VM with the reviewed OpenTofu plan and
configuration:

- VM ID, name, node, running state, and lock state
- ownership, environment, and role tags
- CPU type and core count
- maximum and ballooned memory values
- boot disk and every additional disk, including interface and size
- SCSI controller, IO thread, discard, cache, and file-format settings
- network bridge and cloud-init address intent
- guest-agent reported addresses when the agent is enabled

If an authorized Proxmox shell is part of the operator workflow, these read-only
commands provide the corresponding status and configuration. Replace the
placeholder with the reviewed output value:

```bash
qm status <vm-id>
qm config <vm-id>
```

Treat `qm config` output as operational data and do not copy it into the public
repository.

## Check for Drift

From the `platform-infra` repository root, run a normal refreshed plan for the
selected environment:

```bash
~/.local/bin/tofu -chdir="environments/<env>" plan
```

The expected result after accepted provisioning is no managed resource action.
Investigate every proposed change. Guest-agent address observations can affect
reported outputs, but they do not justify ignoring a managed VM change.

Plans can contain operational or sensitive values. Keep saved plans outside Git,
restrict their permissions, and remove them when their approved purpose ends.

## Acceptance Checklist

- [ ] The VM key, name, ID, and selected environment agree across configuration,
      state, and Proxmox.
- [ ] The VM is running and unlocked.
- [ ] SSH succeeds with the expected cloud-init user and dedicated per-VM key.
- [ ] The SSH host key was verified through a trusted channel.
- [ ] Hostname, address, and default route match the reviewed intent.
- [ ] CPU, memory, disks, network attachment, and tags match the reviewed shape.
- [ ] The guest agent is active and reports addresses when enabled.
- [ ] No guest storage or service configuration was changed during verification.
- [ ] A refreshed OpenTofu plan contains no unexplained managed resource action.
- [ ] No operational values or sensitive output were added to Git.

For missing SSH keys, cloud-init login failures, empty guest-agent outputs, or
locked VMs, use [Troubleshooting](troubleshooting.md).
