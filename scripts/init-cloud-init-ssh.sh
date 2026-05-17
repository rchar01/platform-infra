#!/bin/sh
set -eu

ssh_config="${SSH_CONFIG:-}"
platform_ssh_init="${PLATFORM_SSH_INIT:-platform-ssh-init}"
empty_passphrase="${SSH_EMPTY_PASSPHRASE:-}"

if [ -z "${ssh_config}" ]; then
  echo "SSH_CONFIG is required" >&2
  exit 1
fi

if [ ! -f "${ssh_config}" ]; then
  echo "${ssh_config} missing; run 'make env' or set SSH_CONFIG/CONFIG_ROOT" >&2
  exit 1
fi

if ! command -v "${platform_ssh_init}" >/dev/null 2>&1; then
  echo "${platform_ssh_init} not found; install platform-tools or set PLATFORM_SSH_INIT=../platform-tools/bin/platform-ssh-init" >&2
  exit 1
fi

if [ -n "${empty_passphrase}" ]; then
  "${platform_ssh_init}" "${ssh_config}" --print-public-key --empty-passphrase
else
  "${platform_ssh_init}" "${ssh_config}" --print-public-key
fi
