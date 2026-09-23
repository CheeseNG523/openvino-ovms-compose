# Validation status — `linux` branch

**Date:** 2026-09-23 (Asia/Kuala_Lumpur / MYT)  
**Base:** `2fc2128` · **Branch:** `linux` (Workshop ship from Forge config-validated spike)

## Honesty labels (live-proof gates)

| Flag | Meaning | State |
| --- | --- | --- |
| **LP-L-CPU** | Live `docker compose --profile cpu up` + `GET /v1/models` (+ chat) on bare-metal/native Linux | **Unproven** |
| **LP-L-GPU** | Live GPU profile (`/dev/dri` + `RENDER_GID`) + `/v1/models` (+ chat) | **Unproven** |
| **LP-L-NPU** | Live NPU profile (`/dev/accel` + Stateful) + `/v1/models` (+ chat) | **Unproven** |
| **LP-IMG** | Pinned tag `openvino/model_server:2026.4.0-gpu` pullability | **Unproven** |

Build box had **no** Docker Engine and **no** `/dev/dri` / `/dev/accel`. Do **not** treat config validation as runtime success.

## What was validated (this spike)

- Compose YAML structure
- `docker compose --profile {cpu,gpu,npu} config` (standalone Compose v2.29.7; no engine)
- Entrypoint / pull-model: `bash -n`; scripts LF / executable
- Resolved config: CPU has CB knobs; GPU has `/dev/dri` + `group_add` RENDER_GID; NPU has Stateful + `max_prompt_len` and **no** CB size/seqs/batched/DSF/prefix in command

## What was **not** proven

- `docker pull` / `compose up` / live OpenAI REST
- Whether the image includes `curl`/`wget` (healthcheck fails closed otherwise)
- Intel GPU or NPU passthrough
- End-to-end `--api_key_file` / prefix / DSF / idle unload against a live OVMS process

Runtime proof needs a Linux host with Docker Engine (and optionally Intel GPU/NPU drivers).
