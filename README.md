# openvino-ovms-compose

Serve [OpenVINO Model Server](https://docs.openvino.ai/2026/model-server/ovms_what_is_openvino_model_server.html) (OVMS) for LLM text generation on a **single host** (CPU / Intel GPU / NPU) with an OpenAI-compatible REST API via Docker Compose.

Public repo target: [CheeseNG523/openvino-ovms-compose](https://github.com/CheeseNG523/openvino-ovms-compose).

> **Honesty:** Forge/Workshop validated **compose config** only on the build box (no Docker Engine / no live chat completion). Runtime proof needs a Docker host (+ optional Intel GPU/NPU). See [docs/VALIDATION_STATUS.md](docs/VALIDATION_STATUS.md).

## Quickstart

**Enable only one Compose profile at a time** — cpu, gpu, and npu all publish the same host ports, so two profiles together will clash.

```bash
cp .env.example .env
# edit SOURCE_MODEL / ports / API_KEY as needed

# CPU (safest; no device nodes required)
docker compose --profile cpu up

# Intel GPU (/dev/dri + RENDER_GID)
docker compose --profile gpu up

# Intel NPU (/dev/accel; Stateful — CB flags are no-ops)
docker compose --profile npu up
```

Health / discovery (REST primary):

```bash
curl -s http://localhost:8000/v1/models | jq .
curl -s http://localhost:8000/v1/config | jq .
```

Chat completion (model name = HF id / served name from `/v1/models`):

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "OpenVINO/Qwen2.5-1.5B-Instruct-int4-ov",
    "messages": [{"role":"user","content":"Say hello in one sentence."}],
    "max_tokens": 64
  }' | jq .
```

If `API_KEY` is set in `.env`, pass `-H "Authorization: Bearer $API_KEY"` (or OpenAI client `api_key=`).

Client `base_url`: `http://localhost:8000/v1`.

gRPC is also published on `GRPC_PORT` (default 9000); REST is primary for tests/docs.

### Serving mode (this repo)

Default path: `--source_model` + `--task text_generation` + `--pull` into `/models`. The OVMS multi-model `--config_path /models/config.json` mode is **not** used here (out of scope / not wired). Do not expect a `config.json` in this repo.

### OpenAI Python client

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="",  # or the value of API_KEY from .env
)
resp = client.chat.completions.create(
    model="OpenVINO/Qwen2.5-1.5B-Instruct-int4-ov",
    messages=[{"role": "user", "content": "Say hello in one sentence."}],
    max_tokens=64,
)
print(resp.choices[0].message.content)
```

## Image pin

`openvino/model_server:2026.4.0-gpu` — use the GPU-capable tag even for CPU (accel path needs it; CPU works on the same image). No custom Dockerfile required.

## Volumes

`./models:/models:rw` — RW required so `--pull` can write HF media into the repo.

## Auth (`API_KEY`)

| `.env` | Behavior |
| --- | --- |
| `API_KEY=` (empty, default) | No authorization required (copy-paste DX / localhost). |
| `API_KEY=secret` | `scripts/entrypoint.sh` writes `/tmp/ovms_api_key` and starts OVMS with `--api_key_file`. Clients must send `Authorization: Bearer <key>`. |

OVMS also honors the `API_KEY` environment variable when `--api_key_file` is omitted ([parameters docs](https://docs.openvino.ai/2026/model-server/ovms_docs_parameters.html)). This compose always prefers the file path when the env value is non-empty.

Set `API_KEY` before exposing beyond localhost.

## Prefix caching (`ENABLE_PREFIX_CACHING`)

When `ENABLE_PREFIX_CACHING=1`, the entrypoint appends `--enable_prefix_caching` for **cpu** and **gpu** profiles only.

On **npu** (Stateful), prefix caching is a documented **no-op** — the entrypoint never injects the flag (`OVMS_DEVICE=NPU`).

## Dynamic split fuse + idle unload

| Knob | Behavior |
| --- | --- |
| `DYNAMIC_SPLIT_FUSE=1` | Entrypoint appends `--dynamic_split_fuse` for **cpu/gpu** only. Default `0` (off). NPU: no-op (skipped). |
| `IDLE_UNLOAD_TIMEOUT_SECONDS=<n>` | When set and non-empty (including `0`), entrypoint appends `--idle_unload_timeout_seconds <n>` for **all** devices (OVMS-specific; OK on NPU). Leave empty/unset to omit. |

## Device notes

| Profile | Host needs | Compose devices | `--target_device` |
| --- | --- | --- | --- |
| `cpu` | none | none | `CPU` |
| `gpu` | `/dev/dri`, render group | `/dev/dri` + `group_add: RENDER_GID` | `GPU` |
| `npu` | `/dev/accel` (+ dri) | accel + dri + render | `NPU` + `--pipeline_type Stateful` |

NPU is **never** auto-selected. Set the profile explicitly. Run **one profile at a time** (shared host ports).

Find render GID: `getent group render | cut -d: -f3` (often `109` or `110`). Set `RENDER_GID` in `.env`.

### NPU Stateful — flags that are NO-OPS

Do **not** treat these as effective with `--profile npu`:

- `cache_size`
- dynamic split fuse (DSF) / `DYNAMIC_SPLIT_FUSE`
- `max_num_batched_tokens`
- `max_num_seqs`
- prefix caching (`ENABLE_PREFIX_CACHING`)
- eviction / sparse attention (related CB knobs)

Use `--max_prompt_len` and INT4 NPU-friendly exports (`*-int4-cw-ov` when listed). Prefer INT4 `--sym --ratio 1.0 --group-size -1` at export time.

### No multi-GPU TP

Tensor parallel / multi-GPU is an **explicit non-goal**. OVMS multi-GPU TP has known gaps ([openvinotoolkit/model_server#3816](https://github.com/openvinotoolkit/model_server/issues/3816)). Single device only — do not add TP env vars.

## Healthcheck

Compose healthcheck probes `GET http://127.0.0.1:${REST_PORT}/v1/models`:

1. Prefer `curl -sf` if present in the image
2. Else `wget -q -O /dev/null`
3. Else **fail closed** (container stays unhealthy until you exec a manual check)

When `API_KEY` is **non-empty**, the probe sends `Authorization: Bearer $API_KEY` (`curl -H` / `wget --header=`). When empty, the probe stays unauthenticated.

`start_period: 300s` is intentional: first `--pull` + model load can take several minutes. Do not shorten it without reason.

Manual check from the host:

```bash
curl -sf http://localhost:8000/v1/models
# with auth:
# curl -sf -H "Authorization: Bearer $API_KEY" http://localhost:8000/v1/models
# KServe-style (if enabled in your image):
# curl -sf http://localhost:8000/v2/health/live
# curl -sf http://localhost:8000/v2/health/ready
```

## WSL2

On WSL2 with Intel GPU passthrough you typically need:

- device `/dev/dxg`
- bind-mount host WSL libs, e.g. `/usr/lib/wsl` → container `/usr/lib/wsl`
- still use the `*-gpu` image tag

Example sketch (not the default service — add under `ovms-gpu` or a custom override when on WSL):

```yaml
devices:
  - /dev/dxg
volumes:
  - ./models:/models:rw
  - /usr/lib/wsl:/usr/lib/wsl
  - ./scripts/entrypoint.sh:/usr/local/bin/ovms-entrypoint.sh:ro
```

Confirm your distro’s Level Zero / oneAPI driver story; WSL paths vary. Native Linux is the better-supported path.

## Optional model pull helper

```bash
./scripts/pull-model.sh
# or: SOURCE_MODEL=OpenVINO/other-int4-ov ./scripts/pull-model.sh
```

Uses the same image + `--pull` into `./models`. Requires Docker on the host.

## OVMS ↔ vLLM flag map

See [docs/VLLM_FLAG_MAP.md](docs/VLLM_FLAG_MAP.md) and comments in `.env.example`.

## Pitfalls

- RO mount + `--pull` → write failure → keep `:rw`
- Wrong UID / missing render group → permission denied on dri/accel — set `HOST_UID`/`HOST_GID`/`RENDER_GID` and uncomment `user:` if needed
- Healthcheck before model load → generous `start_period` (300s); first pull can be large
- Healthcheck fails closed if the image has neither `curl` nor `wget` — check manually from the host
- Two profiles at once → host port clash (unsupported)
- Missing `HF_TOKEN` on gated models → 401
- Switching profile/device → `docker compose --profile <new> up -d --force-recreate`
- Classic TensorFlow Serving model layout for LLMs → discontinued; this project is GenAI `text_generation` only
- Expecting multi-GPU TP → unsupported here (#3816)
- Expecting `--config_path` multi-model → not wired in this repo

## Layout

```
openvino-ovms-compose/
  docker-compose.yml      # profiles: cpu | gpu | npu (one at a time)
  .env.example
  README.md
  models/.gitkeep         # weights gitignored
  scripts/
    entrypoint.sh         # API_KEY / prefix / DSF / idle injection
    pull-model.sh
  docs/
    VLLM_FLAG_MAP.md
    VALIDATION_STATUS.md
```
