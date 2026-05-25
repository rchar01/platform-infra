#!/bin/sh
set -eu

platform_ssh_init="${PLATFORM_SSH_INIT:-platform-ssh-init}"
empty_passphrase="${SSH_EMPTY_PASSPHRASE:-}"
env_name="${ENV:-homelab}"
env_dir="${ENV_DIR:-environments/${env_name}}"
tfvars="${TFVARS:-}"
ssh_key_dir="${SSH_KEY_DIR:-${HOME}/.ssh}"
ssh_key_prefix="${SSH_KEY_PREFIX:-platform-infra}"

case "${ssh_key_dir}" in
  "~") ssh_key_dir="${HOME}" ;;
  "~/"*) ssh_key_dir="${HOME}/${ssh_key_dir#~/}" ;;
esac

if [ -z "${tfvars}" ]; then
  echo "TFVARS is required" >&2
  exit 1
fi

if ! command -v "${platform_ssh_init}" >/dev/null 2>&1; then
  echo "${platform_ssh_init} not found; install platform-tools or set PLATFORM_SSH_INIT=../platform-tools/bin/platform-ssh-init" >&2
  exit 1
fi

if [ ! -d "${env_dir}" ]; then
  echo "${env_dir} missing" >&2
  exit 1
fi

if [ ! -f "${tfvars}" ]; then
  echo "${tfvars} missing; run 'make env' or set TFVARS/CONFIG_ROOT" >&2
  exit 1
fi

extract_vm_names() {
  awk '
    /^[[:space:]]*vms[[:space:]]*=[[:space:]]*{/ {
      in_vms = 1
      next
    }
    in_vms && /^}/ {
      in_vms = 0
      next
    }
    in_vms && /^  / {
      line = $0
      if (line ~ /^  "?[A-Za-z0-9_.-]+"?[[:space:]]*=[[:space:]]*{/) {
        sub(/^[[:space:]]*/, "", line)
        sub(/[[:space:]]*=.*/, "", line)
        gsub(/^"|"$/, "", line)
        print line
      }
    }
  ' "${tfvars}"
}

vm_names=$(extract_vm_names)

if [ -z "${vm_names}" ]; then
  echo "No VMs found in ${tfvars}; no cloud-init SSH keys generated"
  exit 0
fi

while IFS= read -r vm_name; do
  if [ -z "${vm_name}" ]; then
    continue
  fi

  key_path="${ssh_key_dir%/}/${ssh_key_prefix}-${env_name}-${vm_name}-cloud-init_ed25519"
  key_comment="${ssh_key_prefix} ${env_name} ${vm_name} cloud-init"

  if [ -n "${empty_passphrase}" ]; then
    "${platform_ssh_init}" \
      --key-path "${key_path}" \
      --comment "${key_comment}" \
      --print-public-key \
      --empty-passphrase
  else
    "${platform_ssh_init}" \
      --key-path "${key_path}" \
      --comment "${key_comment}" \
      --print-public-key
  fi
done <<EOF
${vm_names}
EOF
