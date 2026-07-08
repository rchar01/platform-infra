# Roadmap

This repository should stay small until the first independent environment provisioning milestone is reliable.

## Current Milestone

Provision an environment bastion VM from an existing Proxmox template, then keep `dev` as a separate state root for independent VM sets.

Acceptance targets:

- `tofu init` succeeds
- `tofu validate` succeeds
- native `tofu plan` with the selected environment tfvars shows the expected VM changes
- native `tofu apply` creates the VM
- The VM boots
- Cloud-init injects the SSH key
- SSH works as the configured cloud-init user
- `tofu destroy` removes the VM
- `homelab.tfvars` is used only from `environments/homelab`
- `dev.tfvars` is used only from `environments/dev`

## Deferred Work

Intentionally deferred until basic provisioning works:

- Least-privilege Proxmox role for the API token
- Remote state backend
- Static IP validation beyond basic CIDR input
- Multi-node Proxmox behavior
- Generated Ansible inventory files
- Rich VM profile abstraction
- Additional real host definitions beyond the included example environment roots
- CI workflow implementation once project tooling stabilizes
- CI apply after remote state with locking exists

## Out Of Scope

Do not add these features here:

- Template building
- Image downloads
- `qm importdisk`
- OS package installation
- `fstab`
- NFS mounts
- Users beyond the initial cloud-init user
- Guest firewall rules
- Docker or Podman setup
- Application configuration
- Systemd services
- Backup scripts inside VMs
- Certificates inside services
- Ansible roles or playbooks
- Kubernetes tooling
- Kubernetes manifests
- Certificate authority management
- Application deployment
