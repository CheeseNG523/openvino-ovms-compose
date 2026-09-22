#!/usr/bin/env bash
# Pull SOURCE_MODEL into ./models via the official OVMS image (--pull).
# Usage: ./scripts/pull-model.sh
#        SOURCE_MODEL=OpenVINO/foo-int4-ov ./scripts/pull-model.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

IMAGE="${OVMS_IMAGE:-openvino/model_server:2026.4.0-gpu}"
SOURCE_MODEL="${SOURCE_MODEL:-OpenVINO/Qwen2.5-1.5B-Instruct-int4-ov}"
TARGET_DEVICE="${TARGET_DEVICE:-CPU}"
REST_PORT="${REST_PORT:-8000}"

mkdir -p models

echo "Pulling ${SOURCE_MODEL} into ./models via ${IMAGE} (device=${TARGET_DEVICE})..."
exec docker run --rm \
  -v "${ROOT}/models:/models:rw" \
  -e HF_TOKEN="${HF_TOKEN:-}" \
  -p "${REST_PORT}:${REST_PORT}" \
  "${IMAGE}" \
  --rest_port "${REST_PORT}" \
  --model_repository_path /models \
  --source_model "${SOURCE_MODEL}" \
  --task text_generation \
  --target_device "${TARGET_DEVICE}" \
  --pull \
  --cache_dir /models/.ovms_cache
