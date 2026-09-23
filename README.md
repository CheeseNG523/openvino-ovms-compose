# openvino-ovms-compose — **`windows` branch**

Serve [OpenVINO Model Server](https://docs.openvino.ai/2026/model-server/ovms_what_is_openvino_model_server.html) (OVMS) for LLM text generation via Docker Compose on **Windows Docker Desktop with WSL2 backend**, using the official **Linux** Hub image (not Windows containers).

**Branch:** `windows` (profiles `cpu` | `gpu` only). For bare-metal Linux GPU (`/dev/dri`) and NPU (`/dev/accel`), use the sibling **`linux`** branch.

Public repo target: [CheeseNG523/openvino-ovms-compose](https://github.com/CheeseNG523/openvino-ovms-compose).

> **Honesty:** Config-validated only (Linux build box; no Docker Desktop). **LP-W-CPU** / **LP-W-GPU** (experimental) / **LP-W-GPU-LDLP** / **LP-IMG** remain **Unproven**. **LP-W-NPU** = expect-fail / out of scope. See [docs/VALIDATION_STATUS.md](docs/VALIDATION_STATUS.md).

## Prerequisites (Docker Desktop WSL2)

1. **Docker Desktop** with **WSL2** backend enabled (not Hyper-V-only legacy; not Windows containers mode for this stack).
2. Clone this repo **on the WSL filesystem** (e.g. `~/src/...` inside your distro), **not** on `C:\...` DrvFs — DrvFs is slow and causes permission traps for `./models` RW mounts.
3. Confirm Intel GPU visibility **inside WSL** before expecting the gpu profile to work:
   - `/dev/dxg` exists in the WSL distro
   - Desktop “Use the WSL 2 based engine” + any GPU option does **not** automatically mean Intel GPU works (NVIDIA-oriented Desktop GPU UX ≠ Intel `/dev/dxg` path)
4. Windows **firewall**: allow inbound TCP **8000** (REST) and **9000** (gRPC) if clients run outside the WSL/Docker NAT path you expect.
5. Keep scripts LF-ended (`.gitattributes` forces LF for `scripts/*.sh`). CRLF on `entrypoint.sh` breaks the Linux container shebang.

## Quickstart

**Enable only one Compose profile at a time** — cpu and gpu publish the same host ports.

There is **no** `npu` profile on this branch: `docker compose --profile npu …` matches nothing (empty project), not an NPU service. Use the `linux` branch or `ovms.exe` for NPU.

```bash
# Inside WSL, repo root on WSL fs:
cp .env.example .env
# edit SOURCE_MODEL / ports / API_KEY as needed

# CPU (safest; no device nodes required)
docker compose --profile cpu up

# Intel GPU via WSL2 (/dev/dxg + /usr/lib/wsl) — EXPERIMENTAL until LP-W-GPU proven
docker compose --profile gpu up
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

`openvino/model_server:2026.4.0-gpu` — official **Linux** image. Use this tag even for CPU. No Windows container image; no custom Dockerfile required.

## Volumes

- `./models:/models:rw` — RW required so `--pull` can write HF media.
- GPU profile also mounts `/usr/lib/wsl:/usr/lib/wsl:ro` (WSL GPU user-mode libs). If smoke fails on Level Zero / missing `.so`, try setting `LD_LIBRARY_PATH=/usr/lib/wsl/lib` in the gpu service env (record as **LP-W-GPU-LDLP**).

## Auth (`API_KEY`)

| `.env` | Behavior |
| --- | --- |
| `API_KEY=` (empty, default) | No authorization required (copy-paste DX / localhost). |
| `API_KEY=secret` | `scripts/entrypoint.sh` writes `/tmp/ovms_api_key` and starts OVMS with `--api_key_file`. Clients must send `Authorization: Bearer <key>`. |

Set `API_KEY` before exposing beyond localhost.

## Prefix caching / DSF / idle unload

| Knob | Behavior |
| --- | --- |
| `ENABLE_PREFIX_CACHING=1` | Entrypoint appends `--enable_prefix_caching` for **cpu** and **gpu**. |
| `DYNAMIC_SPLIT_FUSE=1` | Entrypoint appends `--dynamic_split_fuse` for **cpu/gpu**. Default `0`. |
| `IDLE_UNLOAD_TIMEOUT_SECONDS=<n>` | When set and non-empty (including `0`), entrypoint appends `--idle_unload_timeout_seconds <n>`. Leave empty to omit. |

## Device notes (this branch)

| Profile | Host needs | Compose devices / volumes | `--target_device` |
| --- | --- | --- | --- |
| `cpu` | none | none | `CPU` |
| `gpu` | `/dev/dxg` inside WSL; WSL libs | `/dev/dxg` + volume `/usr/lib/wsl` (**no** `group_add` / `RENDER_GID`) | `GPU` |

**Do not** copy linux-branch `/dev/dri` + `RENDER_GID` onto this branch — wrong bind for Docker Desktop WSL2.

Run **one profile at a time** (shared host ports).

### NPU — out of scope on this branch

NPU via Compose on Windows/WSL2 is **not** supported here (`/dev/accel` is not usable for this stack in WSL2). There is **no** `ovms-npu` service and no npu profile.

- Native Windows binary path: use **`ovms.exe`** (outside this Compose repo).
- Or run the sibling **`linux`** branch on bare-metal Linux with `/dev/accel`.

**LP-W-NPU** = expect-fail / OOS by design.

### No multi-GPU TP

Tensor parallel / multi-GPU is an **explicit non-goal** ([openvinotoolkit/model_server#3816](https://github.com/openvinotoolkit/model_server/issues/3816)). Single device only.

## Host user mapping (`user:`)

Compose keeps `user: "${HOST_UID}:${HOST_GID}"` **commented out**. Uncomment only if `./models` hits permission errors; set `HOST_UID` / `HOST_GID` in `.env`.

`RENDER_GID` is **unused** on this branch (linux GPU/NPU only).

## Healthcheck

Probes `GET http://127.0.0.1:${REST_PORT}/v1/models` with curl → wget → fail closed. Auth-aware when `API_KEY` is non-empty. `start_period: 300s` for first `--pull`.

## Optional model pull helpers

Inside WSL:

```bash
./scripts/pull-model.sh
# or: SOURCE_MODEL=OpenVINO/other-int4-ov ./scripts/pull-model.sh
```

From PowerShell (host), if the repo lives on a WSL path:

```powershell
.\scripts\pull-model.ps1
```

Uses the same image + `--pull` into `./models`. Requires Docker reachable from the environment that runs the script.

## OVMS ↔ vLLM flag map

See [docs/VLLM_FLAG_MAP.md](docs/VLLM_FLAG_MAP.md) and comments in `.env.example`.

## Pitfalls

- Clone on **DrvFs** (`C:\...`) → slow I/O / weird perms — use WSL fs
- CRLF on `scripts/entrypoint.sh` → container start failure — keep LF (`.gitattributes`)
- Expecting linux `/dev/dri` + `RENDER_GID` on WSL2 → wrong; use this branch’s dxg + wsl volume
- Desktop “GPU” enabled but no `/dev/dxg` in WSL → Intel path still broken
- Firewall blocking 8000/9000 → clients cannot reach API
- Expecting NPU Compose profile → OOS; use `ovms.exe` or `linux` branch
- RO mount + `--pull` → write failure → keep `:rw`
- Two profiles at once → host port clash
- Missing `HF_TOKEN` on gated models → 401
- Claiming live GPU without flipping **LP-W-GPU** → false confidence (treat as experimental)
- Expecting multi-GPU TP → unsupported (#3816)

## Layout

```
openvino-ovms-compose/   # windows branch
  docker-compose.yml      # profiles: cpu | gpu (no npu)
  .env.example
  .gitattributes          # LF for scripts/*.sh
  README.md
  models/.gitkeep
  scripts/
    entrypoint.sh         # API_KEY / prefix / DSF / idle injection (LF)
    pull-model.sh         # run inside WSL
    pull-model.ps1        # optional: wsl -e wrapper from PowerShell
  docs/
    VLLM_FLAG_MAP.md
    VALIDATION_STATUS.md
```
