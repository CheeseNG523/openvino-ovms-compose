# OVMS ↔ vLLM flag map

Compose / `.env` knobs mapped to familiar vLLM serving flags. Mapping quality notes from design Scout review.

| Compose / `.env` / OVMS | vLLM analogue | Quality |
| --- | --- | --- |
| `REST_PORT` / `--rest_port` | serve port | Good |
| `API_KEY` / `--api_key_file` | `--api-key` | Good |
| `SOURCE_MODEL` / model name in API | `--model` | Good |
| `--max_num_seqs` | `--max-num-seqs` | Good |
| `--max_num_batched_tokens` | `--max-num-batched-tokens` | Good |
| `--enable_prefix_caching` | `--enable-prefix-caching` | Good |
| OpenAI `base_url .../v1` | same | Good |
| `--cache_size` / KV knobs | `--gpu-memory-utilization` / KV | Thin |
| (n/a — no TP) | `--tensor-parallel-size` | Thin / **avoid** ([OVMS #3816](https://github.com/openvinotoolkit/model_server/issues/3816)) |
| export-time precision / OV IR | `--dtype` | Approx |
| Continuous batching CPU/GPU | CB | Good on CPU/GPU; NPU Stateful queued |
| `--max_prompt_len` (NPU) | related to max model len | Thin |
| `--pipeline_type` (NPU → Stateful) | (no direct) | NPU-specific |
| `--idle_unload_timeout_seconds` | (idle GC) | OVMS-specific |
| `--kv_cache_precision u8` | KV quant | Approx |
| `--dynamic_split_fuse` | (scheduler) | OVMS GenAI |
| `--target_device` | device placement | OVMS-specific |

## How this repo wires selected flags

| Knob | Wiring |
| --- | --- |
| `API_KEY` | Empty → no auth. Non-empty → `scripts/entrypoint.sh` writes `/tmp/ovms_api_key` and adds `--api_key_file`. OVMS also reads env `API_KEY` if the file flag is omitted. |
| `ENABLE_PREFIX_CACHING=1` | Entrypoint appends `--enable_prefix_caching` for **cpu/gpu** only (`OVMS_DEVICE≠NPU`). |
| `ENABLE_PREFIX_CACHING` on NPU | No-op: entrypoint skips injection; do not treat as effective. |

## NPU Stateful ignores (no-ops)

`cache_size`, DSF, `max_num_batched_tokens`, `max_num_seqs`, prefix caching, eviction, sparse attention.

## Non-goal: multi-GPU / tensor parallel

This project intentionally does **not** expose `--tensor-parallel-size` / multi-GPU TP. OVMS multi-GPU TP support has known gaps (GitHub issue [#3816](https://github.com/openvinotoolkit/model_server/issues/3816)). Single device only.
