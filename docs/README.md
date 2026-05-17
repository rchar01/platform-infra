# Documentation

This directory documents how `platform-infra` fits into the platform workspace and how to operate its OpenTofu environments.

## Start Here

Read `workflow.md` first. It is the canonical step-by-step guide for local private setup, homelab and dev operations, validation-only checks, fallback testing, destroy, and CI workflow shape.

Then use the supporting docs as references.

| Task | Document |
| --- | --- |
| Run the private workflow step by step | `workflow.md` |
| Confirm local, Proxmox, template, and CI prerequisites | `requirements.md` |
| Bootstrap and store the Proxmox API token | `proxmox-api-token.md` |
| Understand local state, lock files, and remote-state requirements | `state.md` |
| Design CI validation, plan, and apply jobs | `ci.md` |
| Choose VM names and VM IDs | `naming-conventions.md` |
| Debug provisioning failures | `troubleshooting.md` |
| Review intentionally deferred work | `roadmap.md` |

## Boundary

`platform-infra` owns VM existence and VM shape, not inside-OS configuration.

This repository provisions VMs from existing templates with the right virtual hardware, network attachment, initial cloud-init access, and handoff outputs. It does not build templates, install operating system packages, configure `fstab` or NFS mounts, run Ansible roles, deploy applications, create service certificates, or manage Kubernetes manifests/tooling.
