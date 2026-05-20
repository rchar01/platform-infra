# Troubleshooting

Use this guide for common first-run failures in `platform-infra`.

## `tofu` Command Not Found

Install the repo-pinned OpenTofu version from the repository root:

```bash
make deps
```

This installs OpenTofu into `~/.local/bin/tofu` by default.

`make deps` is idempotent. If the expected OpenTofu version is already installed in the configured `TOFU_INSTALL_DIR`, it skips the download.

If `tofu` is still not found for direct shell use, either run `~/.local/bin/tofu` explicitly or add `~/.local/bin` to `PATH`. For CI or repo-local isolation, use:

```bash
make deps TOFU_INSTALL_DIR="$PWD/.tools/bin"
```

## Provider Download Fails

Run from the repository root:

```bash
make init
```

Check local network access to the provider registry and retry. If `.terraform.lock.hcl` changes after a successful retry, review and commit it.

## Native `tofu plan` Says A tfvars File Is Missing

For the normal private workflow, create or check the private tfvars file:

```bash
make env ENV=homelab PRIVATE=1
$EDITOR ../platform-private/infra/homelab.tfvars
```

Use `ENV=dev` for `../platform-private/infra/dev.tfvars`.

Only create a local ignored `terraform.tfvars` for isolated fallback testing:

```bash
make env
$EDITOR environments/homelab/terraform.tfvars
```

The generated `terraform.tfvars` file is ignored and should not be committed.

If using the private sourced workflow, also confirm that the matching local args file exists and has been sourced from the environment root:

The relative `../../../platform-private/...` path assumes the command is run from an `environments/<env>` root.

```bash
source "../../../platform-private/infra/homelab.tofu.env"
env | grep '^TF_CLI_ARGS_'
```

Use `dev.tofu.env` for the same check in the dev root. The env file should point `TF_CLI_ARGS_plan`, `TF_CLI_ARGS_apply`, and `TF_CLI_ARGS_destroy` at the matching environment tfvars file.

OpenTofu also auto-loads `terraform.tfvars` from the current environment root. If private workflow plans are using unexpected values, check for a local ignored `terraform.tfvars` that contains stale `proxmox_api_token`, `proxmox_api_token_file`, or other conflicting variables.

## Authentication Fails

Check `proxmox_endpoint` in the selected tfvars file and the token file referenced by `proxmox_api_token_file`, normally `~/.config/platform-infrastructure/proxmox-token`.

The expected token shape is:

```text
tofu@pve!homelab=TOKEN_SECRET
```

Confirm the token has permission to clone and manage VMs. The first homelab setup may use `Administrator`; reduce privileges later after the workflow works.

The documented default identity is `tofu@pve!homelab`. If `platform-tools` is available on your operator workstation, check the Proxmox bootstrap prerequisites over SSH:

```bash
platform-proxmox-token-init --ssh root@<proxmox-ip> --check
```

To check the automatic token-file workflow, include the token file path:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --write-token-file ~/.config/platform-infrastructure/proxmox-token \
  --check
```

Without `--write-token-file`, check mode validates the manual token output workflow and treats remote `jq` as optional. With `--write-token-file`, check mode validates the automatic token-file workflow and requires remote `jq`. A non-empty local token file fails the automatic workflow unless `--force` is used intentionally.

If you intentionally use a different realm, the token line must match it. For example, a PAM user named `tofu` requires `tofu@pam!homelab=TOKEN_SECRET`, not `tofu@pve!homelab=TOKEN_SECRET`.

Confirm the token file exists, contains only the token value, and is readable only by your user:

```bash
stat -c '%a %n' ~/.config/platform-infrastructure ~/.config/platform-infrastructure/proxmox-token
```

Verify the token against the Proxmox API from the operator workstation:

The `-k` flag below is for authentication diagnostics against an untrusted certificate only; it is not the default OpenTofu TLS posture.

```bash
curl -kfsS \
  -H "Authorization: PVEAPIToken=$(< ~/.config/platform-infrastructure/proxmox-token)" \
  https://<proxmox-ip>:8006/api2/json/version
```

If this returns version data, the token authenticates. If it returns `401 Unauthorized`, recreate the Proxmox token and overwrite the local token file intentionally because Proxmox cannot reveal an existing token secret. If the connection fails before authentication, check the endpoint, port `8006`, routing, firewall, and TLS behavior.

If OpenTofu fails with a certificate verification error, fix local trust for the Proxmox API certificate first. The examples intentionally use `proxmox_insecure = false`. Use `proxmox_insecure = true` only as an explicit private/local override after accepting that a MITM-capable network path could expose or alter token-authenticated API traffic.

If using `proxmox_api_token_file`, remember that relative paths are resolved from the `config_root` value passed to `tofu plan` or `tofu apply`. In the private sourced workflow, `config_root` comes from the matching `*.tofu.env` file.

## Cloud-Init SSH Key Missing

If `tofu plan` reports that a per-VM SSH public key file does not exist, generate the environment keys with `platform-ssh-init` through the Make wrapper:

```bash
make init-ssh PRIVATE=1
```

For local fallback config:

```bash
make init-ssh
```

Use `ENV=dev PRIVATE=1` for dev keys.

The default per-VM key path pattern is:

```text
~/.ssh/platform-infra-<env>-<vm-key>-cloud-init_ed25519
```

If `platform-ssh-init` is not installed, install `platform-tools` or pass the tool path:

```bash
make init-ssh PLATFORM_SSH_INIT=../platform-tools/bin/platform-ssh-init
```

## Template VM ID Not Found

Confirm `template_vm_id` points to an existing Proxmox template.

Template creation belongs in `platform-template-builder`; do not add template creation logic here.

## Datastore Or Bridge Not Found

Confirm these values match Proxmox exactly:

- `default_datastore`
- `default_cloud_init_datastore`
- `default_bridge`
- Per-VM datastore or bridge overrides

Names are case-sensitive and environment-specific.

## Cloud-Init SSH Key Not Injected

Confirm the per-VM public key file exists, or that the VM has an explicit per-VM `ssh_public_key_file` or `ssh_public_key`, and that the template supports cloud-init.

Confirm the login user matches `cloud_init_username`. The default is `rocky`.

If the image has a different default cloud-init user, set:

```hcl
cloud_init_username = "ansible"
```

## Guest Agent IP Outputs Are Empty

The provider only reports guest IP addresses when `qemu-guest-agent` is installed, enabled, running inside the guest, and `agent_enabled = true`.

If the template does not have the guest agent yet, either fix the template in `platform-template-builder` or temporarily set:

```hcl
agent_enabled = false
```

Provisioning can still work without the guest agent, but DHCP lease outputs may be unavailable.

## Destroy Hangs

The module sets `stop_on_destroy = true` to reduce shutdown issues when the guest agent is unavailable.

If a VM is locked in Proxmox, inspect the Proxmox task log before retrying. Do not remove state manually unless you understand the consequences.
