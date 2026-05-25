# Public Repository Checklist

Use this checklist before committing, tagging, or publishing changes from this repository.

## Tracked Content

- Do not commit real `terraform.tfvars`, `*.tfvars.json`, state files, plan files, Proxmox tokens, SSH private keys, or generated `.terraform/` directories.
- Keep public examples fake in identity: use RFC 5737 documentation IP ranges, neutral hostnames, neutral DNS domains, and placeholder token identities.
- Do not use real Proxmox node names, storage pool names, bridge names, VM names, template IDs, VM IDs, VLANs, DNS zones, or hostnames unless they are intentionally public.
- Keep token examples in placeholder form, such as `<automation-user>@<realm>!<token-id>=TOKEN_SECRET`.
- Keep SSH key examples as path patterns only; do not commit public keys from real hosts unless explicitly intended.

## Local Files

- Check ignored local files before publishing with `git status --short --ignored`.
- Treat ignored `terraform.tfstate`, `terraform.tfstate.backup`, `.terraform/`, and `*.tfplan` files as sensitive local artifacts.
- Do not publish raw working-directory archives because ignored local state and provider files may be included.

## Review Commands

Run targeted searches before pushing public docs or examples:

```bash
git grep -n -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.'
git grep -n -E 'BEGIN .*PRIVATE KEY|proxmox_api_token\s*=|TOKEN_SECRET|password|secret'
```

False positives are acceptable, but each match should be intentional and safe for the public repo.
