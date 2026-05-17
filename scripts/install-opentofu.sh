#!/bin/sh
set -eu

version="${TOFU_VERSION:-1.11.7}"
default_install_dir="${HOME}/.local/bin"
install_dir="${TOFU_INSTALL_DIR:-${default_install_dir}}"
tofu_bin="${install_dir}/tofu"

warn_path() {
  if [ "${install_dir}" != "${default_install_dir}" ]; then
    return 0
  fi

  case ":${PATH}:" in
    *:"${install_dir}":*) ;;
    *)
      echo "warning: ${install_dir} is not in PATH; use ${tofu_bin} directly or update PATH" >&2
      ;;
  esac
}

if [ -x "${tofu_bin}" ]; then
  installed_version=$("${tofu_bin}" version 2>/dev/null | awk 'NR == 1 { print $2 }')
  if [ "${installed_version}" = "v${version}" ]; then
    "${tofu_bin}" version
    warn_path
    exit 0
  fi
fi

os=$(uname -s | tr '[:upper:]' '[:lower:]')
case "${os}" in
  linux|darwin) ;;
  *)
    echo "unsupported OS: ${os}" >&2
    exit 1
    ;;
esac

machine=$(uname -m)
case "${machine}" in
  x86_64|amd64) arch="amd64" ;;
  aarch64|arm64) arch="arm64" ;;
  *)
    echo "unsupported architecture: ${machine}" >&2
    exit 1
    ;;
esac

for tool in curl unzip awk; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "${tool} not found" >&2
    exit 1
  fi
done

asset="tofu_${version}_${os}_${arch}.zip"
sums="tofu_${version}_SHA256SUMS"
base_url="https://github.com/opentofu/opentofu/releases/download/v${version}"
tmp_dir=$(mktemp -d)

cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT HUP INT TERM

echo "Downloading OpenTofu ${version} for ${os}/${arch}"
curl -fsSL "${base_url}/${asset}" -o "${tmp_dir}/${asset}"
curl -fsSL "${base_url}/${sums}" -o "${tmp_dir}/${sums}"

expected=$(awk -v file="${asset}" '$2 == file { print $1 }' "${tmp_dir}/${sums}")
if [ -z "${expected}" ]; then
  echo "checksum entry not found for ${asset}" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum "${tmp_dir}/${asset}" | awk '{ print $1 }')
elif command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "${tmp_dir}/${asset}" | awk '{ print $1 }')
else
  echo "sha256sum or shasum not found" >&2
  exit 1
fi

if [ "${actual}" != "${expected}" ]; then
  echo "checksum mismatch for ${asset}" >&2
  exit 1
fi

unzip -q "${tmp_dir}/${asset}" -d "${tmp_dir}/tofu"
mkdir -p "${install_dir}"
cp "${tmp_dir}/tofu/tofu" "${tofu_bin}"
chmod 0755 "${tofu_bin}"

"${tofu_bin}" version
warn_path
