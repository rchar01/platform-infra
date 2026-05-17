#!/bin/sh
set -eu

require_var() {
  name="$1"
  eval "value=\${${name}:-}"
  if [ -z "${value}" ]; then
    echo "${name} is required" >&2
    exit 1
  fi
}

copy_if_missing() {
  source_path="$1"
  target_path="$2"
  created_message="$3"
  exists_message="$4"

  mkdir -p "$(dirname "${target_path}")"

  if [ -e "${target_path}" ]; then
    echo "${exists_message}"
    return 0
  fi

  if [ ! -f "${source_path}" ]; then
    echo "${source_path} missing" >&2
    exit 1
  fi

  cp "${source_path}" "${target_path}"
  echo "${created_message}"
}

require_var TFVARS
require_var TFVARS_EXAMPLE
require_var SSH_CONFIG
require_var SSH_CONFIG_EXAMPLE

copy_if_missing \
  "${TFVARS_EXAMPLE}" \
  "${TFVARS}" \
  "Created ${TFVARS}; edit real Proxmox values before planning or applying" \
  "${TFVARS} already exists"

copy_if_missing \
  "${SSH_CONFIG_EXAMPLE}" \
  "${SSH_CONFIG}" \
  "Created ${SSH_CONFIG}; edit SSH key settings before running make init-ssh" \
  "${SSH_CONFIG} already exists"
