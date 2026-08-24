# CI/CD

CI has two distinct modes in this repository: validation without secrets, and environment operations with secrets and state.

## Secret-Free Validation

Run this on every pull request. It verifies formatting, initialization, and static OpenTofu validation without contacting Proxmox or reading private tfvars.

```bash
make verify TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=dev TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=config-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=snapshot-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
make verify ENV=migration-test TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

`make verify` installs the pinned OpenTofu binary through `make deps` when needed.

This mode is safe for public CI because it does not require `TF_VAR_proxmox_api_token`.

## Private Environment Plans

Plan jobs that contact Proxmox should run one environment at a time. Each job must use the matching OpenTofu root and the matching private tfvars file.

CI Proxmox plan jobs should keep TLS verification enabled. Do not set `proxmox_insecure = true` in CI unless the runner network path and certificate trust model have been explicitly reviewed.

### GitLab Proxmox CA Trust

For GitLab jobs, store the Proxmox CA PEM as a protected, environment-scoped
file-type CI/CD variable named `PROXMOX_CA_FILE`. GitLab exposes a file-type
variable as the path to a temporary file, so do not treat its value as the PEM
content. The certificate is not a secret, but it identifies private
infrastructure and should not be committed to this public repository.

Keep `TF_VAR_proxmox_api_token` protected, masked, and scoped to the same
environment. Do not use the token until CA validation and the unauthenticated
TLS check pass. Disable GitLab variable-reference expansion for the token and CA
variables because neither value should interpolate another CI/CD variable.

Each job using environment-scoped variables must declare the matching GitLab
environment. Without this job metadata, GitLab does not expose those variables:

```yaml
<job-name>:
  environment:
    name: <environment-name>
```

For example, variables scoped to `production` require `name: production` on
both the plan and apply jobs. The shell examples below are job bodies and omit
this surrounding GitLab YAML.

Create a temporary combined bundle before `make deps` or any OpenTofu command so
the job trusts both normal public CAs and the Proxmox CA:

```bash
test -s "$PROXMOX_CA_FILE"
openssl x509 -in "$PROXMOX_CA_FILE" -noout -checkend 86400

system_ca_bundle="${SYSTEM_CA_BUNDLE:-/etc/ssl/certs/ca-certificates.crt}"
test -r "$system_ca_bundle"

job_ca_bundle="$(mktemp)"
trap 'rm -f "$job_ca_bundle"' EXIT
chmod 0600 "$job_ca_bundle"
cat "$system_ca_bundle" "$PROXMOX_CA_FILE" >"$job_ca_bundle"
export SSL_CERT_FILE="$job_ca_bundle"

curl --cacert "$SSL_CERT_FILE" \
  --fail --silent --show-error --output /dev/null \
  https://<proxmox-host>:8006/
```

The default `SYSTEM_CA_BUNDLE` path above is used by Debian, Ubuntu, and Alpine
images. Override it for a pinned runner image that stores its public CA bundle
elsewhere. Do not print or persist the combined bundle, and do not include it in
artifacts. Repeat this setup in an apply job because each GitLab job has a new
filesystem and process environment.

After establishing GitLab CA trust, an example homelab plan job body is:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"

cd environments/homelab
../../.tools/bin/tofu init -input=false
../../.tools/bin/tofu plan -input=false -out=homelab.tfplan \
  -var-file="$PWD/../../../platform-private/infra/homelab.tfvars" \
  -var="config_root=$PWD/../../../platform-private/infra"
```

An example dev plan job body is:

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
TF_VAR_proxmox_api_token='<automation-user>@<realm>!<token-id>=TOKEN_SECRET'
```

Do not print the token, write it to a committed file, or store it in `platform-private`.

Saved plan files can contain sensitive values. If a plan file moves between CI jobs, store it only as a protected artifact with restricted access and short retention.

## Private Config In CI

CI needs access to private environment values. Use one of these approaches:

- Check out `platform-private` as a sibling directory beside `platform-infra`.
- Materialize environment-specific tfvars from a secure CI secret or secret manager at runtime.
- Keep per-VM SSH public key references valid for the runner, or pass per-VM `ssh_public_key` values from non-secret CI variables.

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
environments/config-test uses platform-private/infra/config-test.tfvars
environments/snapshot-test uses platform-private/infra/snapshot-test.tfvars
environments/migration-test uses platform-private/infra/migration-test.tfvars
```

Never cross-use tfvars between roots. CI may initialize and validate any
disposable root, but live guest mutation, reboot, snapshot, rollback, apply, and
destroy remain explicitly approved acceptance operations.
