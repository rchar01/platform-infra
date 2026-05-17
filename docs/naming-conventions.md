# Naming Conventions

Use predictable names and VM IDs so templates, infrastructure, and configuration inventory do not collide.

## VM Names

VM names should be lowercase DNS-style names.

Recommended pattern:

```text
<role>-<purpose>-<index>
```

Examples:

- `infra-test-01`
- `monitoring-01`
- `k8s-control-01`
- `k8s-worker-01`

## VM Map Keys

The `vms` map key should usually match `hostname`.

Example:

```hcl
vms = {
  infra-test-01 = {
    hostname = "infra-test-01"
    vm_id    = 101
  }
}
```

Keeping the key and hostname aligned makes OpenTofu plans and outputs easier to read.

## VM IDs

Keep template IDs separate from provisioned VM IDs.

Recommended ranges:

| Range | Use |
| --- | --- |
| `9000-9099` | Proxmox templates built by `platform-template-builder`. |
| `100-8999` | Provisioned VMs managed by `platform-infra`. |

Before assigning a new `vm_id`, confirm it is not already used in Proxmox.

## Template IDs

Set the default template ID with `template_vm_id` in `terraform.tfvars`.

Use a per-VM `template_vm_id` override only when a specific VM intentionally uses a different template.

## Tags

The homelab environment adds these default tags:

- `opentofu`
- `platform-infra`

Add role-specific tags per VM when useful, such as `test`, `monitoring`, or `k8s`.
