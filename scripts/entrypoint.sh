#!/usr/bin/env bash
# OVMS entrypoint wrapper: optional --api_key_file + --enable_prefix_caching.
# Official image binary is typically /ovms/bin/ovms; fall back to PATH.
set -euo pipefail

OVMS_BIN="${OVMS_BIN:-}"
if [[ -z "${OVMS_BIN}" ]]; then
  if [[ -x /ovms/bin/ovms ]]; then
    OVMS_BIN=/ovms/bin/ovms
  elif command -v ovms >/dev/null 2>&1; then
    OVMS_BIN="$(command -v ovms)"
  else
    echo "entrypoint: ovms binary not found (tried /ovms/bin/ovms and PATH)" >&2
    exit 127
  fi
fi

extra=()

# Auth: when API_KEY is non-empty, write a key file and pass --api_key_file.
# When empty, omit the flag (OVMS also honors env API_KEY; empty = no auth).
# Docs: https://docs.openvino.ai/2026/model-server/ovms_docs_parameters.html
API_KEY_VALUE="${API_KEY:-}"
if [[ -n "${API_KEY_VALUE}" ]]; then
  key_file="${OVMS_API_KEY_FILE:-/tmp/ovms_api_key}"
  # Restrict perms; first line is the key OVMS reads.
  umask 077
  printf '%s\n' "${API_KEY_VALUE}" > "${key_file}"
  extra+=(--api_key_file "${key_file}")
fi

# Prefix caching: inject only for CPU/GPU when ENABLE_PREFIX_CACHING=1.
# NPU Stateful treats this as a no-op — never pass it for NPU profiles.
OVMS_DEVICE="${OVMS_DEVICE:-CPU}"
ENABLE_PREFIX_CACHING="${ENABLE_PREFIX_CACHING:-0}"
if [[ "${OVMS_DEVICE}" != "NPU" && "${ENABLE_PREFIX_CACHING}" == "1" ]]; then
  extra+=(--enable_prefix_caching)
fi

exec "${OVMS_BIN}" "$@" "${extra[@]}"
