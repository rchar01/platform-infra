# Proxmox API Token

Use a dedicated Proxmox API token for OpenTofu automation. Do not use root password authentication.

## Apply Identity

The initial homelab workflow expects a Proxmox API token for this automation identity:

- User: `tofu@pve`
- Token ID: `homelab`
- Token format: `tofu@pve!homelab=TOKEN_SECRET`
- Initial role: `Administrator` at `/`

The broad `Administrator` role is acceptable only for first private homelab validation. Replace it with a least-privilege role after basic provisioning works.

With `--privsep 0`, the token inherits the user's ACLs. If you later use a privilege-separated token, grant permissions to the token identity instead of relying on inherited user permissions.

## Helper Workflow

If `platform-tools` is installed on your operator workstation, use `platform-config-init` to provision the local outside-Git config directory before bootstrapping the Proxmox token:

```bash
platform-config-init
```

Then use the shared helper to run the Proxmox bootstrap over SSH.

Check the exact automatic token-file workflow first:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user tofu@pve \
  --token-id homelab \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/infra/proxmox.token \
  --check
```

Then run the same command without `--check` to create the identity and write a newly generated token locally:

```bash
platform-proxmox-token-init \
  --ssh root@<proxmox-ip> \
  --proxmox-user tofu@pve \
  --token-id homelab \
  --role Administrator \
  --path / \
  --write-token-file ~/.config/platform-infrastructure/infra/proxmox.token
```

The token helper creates the `infra/` parent directory when writing the token file.

Use the Proxmox IP address until a trusted hostname or SSH alias exists. `root@pve` only works when `pve` resolves through DNS, `/etc/hosts`, or a `Host pve` block in `~/.ssh/config`.

The helper creates the user if needed, creates the token if needed, grants the initial ACL, and writes the generated token line outside Git.

Automatic token-file writing requires `jq` on the Proxmox host. Without `jq`, omit `--write-token-file`; the helper checks the manual token output workflow and you copy the generated token line manually.

If `~/.config/platform-infrastructure/infra/proxmox.token` is already non-empty, the automatic workflow refuses to overwrite it. Use `--force` only when intentionally replacing the local token file.

Proxmox only shows the token secret when the token is created. If `tofu@pve!homelab` already exists, the helper cannot recover the existing secret; delete and recreate the token if the secret was lost.

See `platform-tools/docs/platform-config-init.md` and `platform-tools/docs/proxmox-token-init.md` in the `platform-tools` repository for helper details and options.

## Manual Fallback Workflow

The manual `pveum` commands are the source-of-truth behavior:

Example Proxmox setup:

```bash
pveum user add tofu@pve --comment "OpenTofu automation user"
pveum user token add tofu@pve homelab --privsep 0
pveum aclmod / -user tofu@pve -role Administrator
```

Store the real token outside every Git repository or in a local secret manager. Never commit the real token.

The normal local setup uses `platform-config-init` to create the directory and placeholder files. If `platform-tools` is unavailable, create the directory and token file manually as a fallback:

```bash
mkdir -p ~/.config/platform-infrastructure/infra
chmod 700 ~/.config/platform-infrastructure ~/.config/platform-infrastructure/infra
$EDITOR ~/.config/platform-infrastructure/infra/proxmox.token
chmod 600 ~/.config/platform-infrastructure/infra/proxmox.token
```

The file should contain only the token value:

```text
tofu@pve!homelab=TOKEN_SECRET
```

Reference that file from local or private tfvars:

```hcl
proxmox_api_token_file = "~/.config/platform-infrastructure/infra/proxmox.token"
```

This avoids exporting the token into a long-lived shell environment. The private config repository may contain this file path, but must not contain the token value.

Verify the token manually from the operator workstation when troubleshooting authentication:

```bash
curl -kfsS \
  -H "Authorization: PVEAPIToken=$(< ~/.config/platform-infrastructure/infra/proxmox.token)" \
  https://<proxmox-ip>:8006/api2/json/version
```

A successful response returns Proxmox version data. `401 Unauthorized` means Proxmox rejected the token identity or secret. This API check proves authentication only; OpenTofu VM operations still require sufficient Proxmox authorization.

In CI, configure the same value as a masked secret named `TF_VAR_proxmox_api_token` or inject it from a secret manager. Do not write the token into `platform-private`, CI artifacts, logs, generated plan summaries, or committed files.

`proxmox_api_token_file` may also point at an environment-specific token file if separate Proxmox tokens are used per environment:

```hcl
proxmox_api_token_file = "~/.config/platform-infrastructure/infra/proxmox-homelab-token"
```

Relative token file paths are resolved from `config_root`, which should match the config directory used by the native OpenTofu command. In the local private workflow, the sourced `*.tofu.env` file sets `config_root` for plan, apply, and destroy.

You can still set `proxmox_api_token` or `TF_VAR_proxmox_api_token` directly for quick testing, but prefer `proxmox_api_token_file` for local operator runs.
