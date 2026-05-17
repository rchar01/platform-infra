# State

OpenTofu state is local for the initial operator workflows.

State files map configuration to real infrastructure and may contain sensitive or environment-specific values. Do not commit them.

For exact plan, apply, and destroy commands, use `workflow.md`.

## Ignored State Files

Ignored state files include:

- `*.tfstate`.
- `*.tfstate.*`.
- Saved plan files such as `*.tfplan`.

## Dependency Lock File

The dependency lock file, `.terraform.lock.hcl`, is created or updated by `tofu init`.

Commit `.terraform.lock.hcl` after `tofu init` succeeds so provider dependency changes can be reviewed. Do not add it to `.gitignore`.

## Environment Isolation

Each directory under `environments/` has independent state:

- `environments/homelab` uses homelab state and `homelab.tfvars`.
- `environments/dev` uses dev state and `dev.tfvars`.

Do not switch independent VM sets by changing only the tfvars file inside one root. OpenTofu treats resources missing from the selected config as candidates for destruction.

Do not create or rely on a local ignored `terraform.tfvars` for the normal private workflow. OpenTofu auto-loads that file from the selected root before applying CLI args, so it can conflict with `../platform-private/infra/<env>.tfvars`.

## Local State

Local state is suitable for the initial single-operator homelab workflow.

Do not manually edit state files as part of normal operation. Use OpenTofu state commands only when intentionally moving, importing, or removing a resource mapping.

Use `tofu destroy` from the selected environment root to remove managed infrastructure. Manual Proxmox deletion can leave stale state and should be reserved for break-glass recovery.

## CI State

Secret-free CI validation can run without state because it only initializes and validates configuration.

CI plans or applies that manage real Proxmox resources need access to the same state used by operators for that environment. An ephemeral runner with fresh local state does not know about existing managed resources and is not safe for apply.

Before CI apply is considered production-grade, add remote state with:

- Encryption at rest.
- Access control limited to operators and CI deployment jobs.
- State locking.
- Separate state per environment root.

Keep the environment invariant unchanged: `environments/homelab` uses homelab state and `homelab.tfvars`; `environments/dev` uses dev state and `dev.tfvars`.
