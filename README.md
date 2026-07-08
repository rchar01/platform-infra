<div align="center">
  <img src="assets/brand/platform-infra-forge-avatar-transparent-512.png" width="256" alt="platform-infra logo">
  <h1>platform-infra</h1>
  <p>Proxmox VM lifecycle infrastructure managed with OpenTofu.</p>
</div>

---

`platform-infra` provisions Proxmox VMs with OpenTofu. It owns whether a VM exists and what virtual hardware, network attachment, initial cloud-init access, and handoff outputs it has.

It does not build templates, configure operating systems after boot, deploy applications, or manage Kubernetes tooling.

Public examples use RFC 5737 documentation addresses from `192.0.2.0/24`; replace them with your own private values before planning or applying.

## Start Here

Read `docs/workflow.md` for the complete step-by-step workflow.

The canonical workflow guide covers:

- One-time local private setup.
- Proxmox token-file setup.
- Private tfvars and SSH key generation.
- Homelab and dev plan/apply steps.
- Environment switching rules.
- Destroy steps.
- Validation-only checks.
- Local fallback testing.
- CI validation, plan, and apply requirements.

Useful entry points:

- `docs/workflow.md`: canonical runbook for all workflows.
- `docs/requirements.md`: local, Proxmox, template, and CI prerequisites.
- `docs/proxmox-api-token.md`: token creation and storage guidance.
- `docs/publication-checklist.md`: public example and artifact review checklist.
- `docs/state.md`: state isolation and remote-state requirements.
- `docs/ci.md`: detailed CI reference.
- `docs/troubleshooting.md`: common first-run failures.

Install the pinned OpenTofu binary and inspect helper targets from the repository root:

```bash
make deps
make help
```

Use Make targets from the repository root for setup, formatting, validation, and SSH key helpers. Use native `tofu` commands from the selected `environments/<env>` root for `plan`, `apply`, `destroy`, and output inspection after sourcing the matching private `.tofu.env` file.

## Platform Project

This repository is one part of a multi-repository platform infrastructure project. The included `homelab` and `dev` roots are example environment names; the same workflow can be adapted for production environments with appropriate state, access control, review, backup, monitoring, and change-management controls.

| Repository | Purpose |
|---|---|
| [`platform-template-builder`](https://codeberg.org/rch/platform-template-builder) | Builds reusable Proxmox VM templates from cloud images. |
| [`platform-infra`](https://codeberg.org/rch/platform-infra) | Provisions platform infrastructure with OpenTofu. |
| [`platform-config`](https://codeberg.org/rch/platform-config) | Configures operating systems and services with Ansible. |
| [`platform-k8s-bastion`](https://codeberg.org/rch/platform-k8s-bastion) | Contains Kubernetes bastion tooling and operational helpers. |
| [`platform-docs`](https://codeberg.org/rch/platform-docs) | Contains architecture notes, runbooks, diagrams, and operational documentation. |
| [`platform-tools`](https://codeberg.org/rch/platform-tools) | Provides shared optional helper tools used by the platform repositories. |

`platform-tools` is not part of the VM lifecycle chain. It provides optional operator/bootstrap helpers used by the platform repositories.

Typical lifecycle:

```text
platform-template-builder
  -> platform-infra
  -> platform-config
  -> platform-k8s-bastion

platform-docs documents the design and operations across all repositories.
```

`platform-infra` starts after a template exists and stops after VMs are provisioned and exposed through OpenTofu outputs.

## Scope

Simple boundary:

```text
platform-infra = VM exists with the right virtual hardware and initial access.
platform-config = VM is configured after boot.
```

In scope:

- Hostnames.
- VM names and VM IDs.
- Proxmox provider configuration.
- VM cloning from an existing template.
- CPU, RAM, boot disk size, and additional virtual disks.
- Datastore, node, and network bridge selection.
- Initial cloud-init user.
- Per-VM SSH public key injection.
- DHCP or static IP intent.
- DNS server and search-domain intent.
- VM tags and descriptions.
- QEMU guest agent flag.
- OpenTofu outputs for later configuration handoff.

Out of scope:

- Cloud image downloads.
- `qm importdisk`.
- Template creation.
- OS package installation.
- `fstab`.
- NFS mounts.
- Users beyond the initial cloud-init user.
- Firewall rules inside the guest.
- Docker or Podman setup.
- Application configuration or deployment.
- Systemd services.
- Backup scripts inside VMs.
- Certificates inside services.
- Kubernetes access tooling or manifests.
- Certificate authority generation.
- Ansible roles or playbooks.

Cloud-init is intentionally minimal here. This repo may set hostname, initial user, SSH key, IP addressing, and DNS intent. Do not use cloud-init in this repo for complex OS configuration.

## Proxmox Disk Performance

For Linux VMs on Proxmox, especially with ZFS-backed storage, the practical target shape is:

- Host storage backed by a ZFS pool when that is the selected Proxmox storage design.
- VM disks on zvol or raw block storage rather than qcow2 files on ZFS.
- SCSI disk interfaces such as `scsi0` and `scsi1` with the `virtio-scsi-single` controller.
- IO thread enabled for VM disks.
- Discard/TRIM enabled so space reclamation can pass through to the underlying storage.
- Disk cache set to `none` by default; use `writeback` only when the durability and power-loss tradeoffs are deliberate.
- Guest filesystems such as XFS or ext4 for typical Linux workloads.

Repository boundary still applies. `platform-infra` may own virtual disk shape, datastore selection, controller, cache, IO thread, and discard settings. `platform-template-builder` owns template image preparation. `platform-config` owns guest partitioning, formatting, filesystems, LVM, mounts, and `fstab`.

Current examples use SCSI disk interfaces and block-style Proxmox datastores, but this module does not yet force `virtio-scsi-single`, disk IO threads, discard/TRIM, or raw file format defaults. Treat those as the preferred direction for future Terraform module changes, and inspect `tofu plan` carefully because changing disk/controller attributes on existing VMs can require shutdowns or affect cloned disk settings.

## Private Workflow

The normal operator workflow uses a sibling private repository for environment values:

```text
../platform-private/infra/
  homelab.tfvars
  dev.tfvars
  homelab.tofu.env
  dev.tofu.env
```

Secrets and key material stay outside Git:

- Proxmox token: `~/.config/platform-infrastructure/infra/proxmox.token`.
- SSH private keys: `~/.ssh`.
- State files and plan files: ignored and not committed.

The private workflow separates public code, private config, local secrets, SSH key material, and independent environment state. That separation supports production-style workflows, but production use still requires environment-specific controls such as remote state with locking, reviewed plans, least-privilege credentials, backups, monitoring, and change management.

Follow `docs/workflow.md` for the exact commands.

## Environments

Each directory under `environments/` is an independent OpenTofu root with separate state.

Current roots:

- `environments/homelab`.
- `environments/dev`.

Do not use `dev.tfvars` from `environments/homelab`, and do not use `homelab.tfvars` from `environments/dev`. Switching VM sets inside one state root can make OpenTofu plan to destroy resources that disappeared from the selected config.

To remove managed VMs, use the destroy workflow in `docs/workflow.md` from the selected environment root. Do not delete OpenTofu-managed VMs manually in Proxmox unless you are intentionally repairing state.

## Secrets Policy

Never commit real environment values, generated state, Proxmox tokens, SSH private keys, or saved plan files.

Commit `.terraform.lock.hcl` after `tofu init` succeeds so provider dependency changes can be reviewed.

## CI/CD

Secret-free validation can run on every pull request with `make verify` for each environment. Proxmox-backed CI plans need private tfvars and a token injected from the CI secret store.

CI apply is not production-grade with ephemeral local state. Add remote state with encryption, access control, and locking before using CI apply.

See `docs/workflow.md` for workflow steps and `docs/ci.md` for detailed CI guidance.
