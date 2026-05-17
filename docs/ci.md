# CI/CD

CI has two distinct modes in this repository: validation without secrets, and environment operations with secrets and state.

## Secret-Free Validation

Run this on every pull request. It verifies formatting, initialization, and static OpenTofu validation without contacting Proxmox or reading private tfvars.

```bash
make verify TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=dev TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

`make verify` installs the pinned OpenTofu binary through `make deps` when needed.

This mode is safe for public CI because it does not require `TF_VAR_proxmox_api_token`.

## Private Environment Plans

Plan jobs that contact Proxmox should run one environment at a time. Each job must use the matching OpenTofu root and the matching private tfvars file.

Example homelab plan job body:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/homelab
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu plan -input=false -out=homelab.tfplan \
  -var-file="$PWD/../../../platform-private/infra/homelab.tfvars" \
  -var="config_root=$PWD/../../../platform-private/infra"
```

Example dev plan job body:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/dev
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu plan -input=false -out=dev.tfplan \
  -var-file="$PWD/../../../platform-private/infra/dev.tfvars" \
  -var="config_root=$PWD/../../../platform-private/infra"
```

The CI platform should inject this environment variable from its secret store:

```bash
TF_VAR_proxmox_api_token='tofu@pve!homelab=TOKEN_SECRET'
```

Do not print the token, write it to a committed file, or store it in `platform-private`.

Saved plan files can contain sensitive values. If a plan file moves between CI jobs, store it only as a protected artifact with restricted access and short retention.

## Private Config In CI

CI needs access to private environment values. Use one of these approaches:

- Check out `platform-private` as a sibling directory beside `platform-infra`.
- Materialize environment-specific tfvars from a secure CI secret or secret manager at runtime.
- Keep SSH public key references valid for the runner, or pass `ssh_public_key` from a non-secret CI variable.

The private tfvars file may contain internal VM names, IPs, bridge names, datastore names, and template IDs. Treat it as confidential even when it does not contain credentials.

The local `*.tofu.env` files are operator convenience wrappers. CI jobs should keep `-var-file` and `config_root` explicit so each job shows exactly which environment it is operating on.

## Apply Jobs

CI apply requires more controls than local operator use.

Minimum controls:

- Remote OpenTofu state with encryption.
- State locking.
- Backend credentials available to both plan and apply jobs.
- Restricted access to state and CI secrets.
- Protected branch or tag rules.
- Manual approval before `tofu apply`.
- Separate jobs per environment.
- No cross-use of tfvars between roots.

Do not run CI apply against ephemeral local state. An ephemeral runner without shared state can create incorrect plans or lose the resource mapping OpenTofu needs to manage existing infrastructure safely.

Manual approval should happen in the CI pipeline gate. The apply job should apply the reviewed saved plan non-interactively instead of creating a new plan during apply:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/homelab
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu apply -input=false homelab.tfplan
```

## Environment Isolation

The invariant is strict:

```text
environments/homelab uses platform-private/infra/homelab.tfvars
environments/dev uses platform-private/infra/dev.tfvars
```

Never run `dev.tfvars` from `environments/homelab`, and never run `homelab.tfvars` from `environments/dev`.
