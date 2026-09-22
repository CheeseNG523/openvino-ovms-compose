#!/usr/bin/env bash
# OVMS entrypoint wrapper: optional --api_key_file, --enable_prefix_caching,
# --dynamic_split_fuse, --idle_unload_timeout_seconds.
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

OVMS_DEVICE="${OVMS_DEVICE:-CPU}"

# Prefix caching: inject only for CPU/GPU when ENABLE_PREFIX_CACHING=1.
# NPU Stateful treats this as a no-op — never pass it for NPU profiles.
ENABLE_PREFIX_CACHING="${ENABLE_PREFIX_CACHING:-0}"
if [[ "${OVMS_DEVICE}" != "NPU" && "${ENABLE_PREFIX_CACHING}" == "1" ]]; then
  extra+=(--enable_prefix_caching)
fi

# Dynamic split fuse (OVMS GenAI scheduler). Pass only when =1 and not NPU
# (NPU Stateful: documented no-op — do not inject).
DYNAMIC_SPLIT_FUSE="${DYNAMIC_SPLIT_FUSE:-0}"
if [[ "${OVMS_DEVICE}" != "NPU" && "${DYNAMIC_SPLIT_FUSE}" == "1" ]]; then
  extra+=(--dynamic_split_fuse)
fi

# Idle unload (OVMS-specific). When set and non-empty (including 0), pass for
# all devices including NPU. Unset / empty in compose → omit the flag.
# Use ${VAR+x} so a literal 0 still counts as "set".
if [[ -n "${IDLE_UNLOAD_TIMEOUT_SECONDS+x}" && -n "${IDLE_UNLOAD_TIMEOUT_SECONDS}" ]]; then
  extra+=(--idle_unload_timeout_seconds "${IDLE_UNLOAD_TIMEOUT_SECONDS}")
fi

exec "${OVMS_BIN}" "$@" "${extra[@]}"
