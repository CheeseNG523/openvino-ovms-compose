# Validation status

**Date:** 2026-09-22 (Asia/Kuala_Lumpur)

## What was validated

- Compose YAML structure (PyYAML parse)
- `docker compose config` for profiles `cpu`, `gpu`, and `npu` (standalone Compose v2.29.7; no Docker Engine required for config)
- Entrypoint / pull-model scripts: `bash -n` syntax check; `chmod +x`
- Resolved config checks: CPU has CB knobs; GPU has `/dev/dri` + render group; NPU has Stateful + `max_prompt_len` and **no** `cache_size` / `max_num_seqs` / `max_num_batched_tokens`

## What was **not** proven on the build box

- `docker pull` of `openvino/model_server:2026.4.0-gpu`
- `docker compose up` / container start
- Live `GET /v1/models` or chat completion
- Whether the official image includes `curl`/`wget` (healthcheck falls back / fails closed)
- Whether `/ovms/bin/ovms` vs `ovms` on PATH matches the pinned tag (entrypoint probes both)
- Intel GPU (`/dev/dri`) or NPU (`/dev/accel`) passthrough
- End-to-end `--api_key_file` / `--enable_prefix_caching` against a live OVMS process

Runtime proof needs a host with Docker Engine (and optionally Intel GPU/NPU drivers). Config validation alone does not equal a serving smoke test.
