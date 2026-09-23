# Validation status — `windows` branch

**Date:** 2026-09-23 (Asia/Kuala_Lumpur / MYT)  
**Base:** `2fc2128` · **Spike:** Forge throwaway (config-only on Linux build box)

## Honesty labels (live-proof gates)

| Flag | Meaning | State |
| --- | --- | --- |
| **LP-W-CPU** | Live `docker compose --profile cpu up` on Docker Desktop WSL2 + `/v1/models` (+ chat) | **Unproven** |
| **LP-W-GPU** | Live GPU profile (`/dev/dxg` + `/usr/lib/wsl`) + `/v1/models` (+ chat) | **Unproven — experimental** until Forge proves on a real DD WSL2 + Intel GPU host |
| **LP-W-GPU-LDLP** | WSL GPU needs `LD_LIBRARY_PATH=/usr/lib/wsl/lib` (or similar) for Level Zero / Intel stack | **Unproven** (compose leaves it commented; document if smoke requires it) |
| **LP-W-NPU** | Windows Compose NPU | **Expect-fail / OOS** — not implemented; use `ovms.exe` or `linux` branch |
| **LP-IMG** | Pinned tag `openvino/model_server:2026.4.0-gpu` pullability | **Unproven** |

Build box: Linux, **no** Docker Engine, **no** `/dev/dxg`. Config validation of the windows YAML does **not** prove WSL2 GPU.

## What was validated (this spike)

- Compose YAML structure (cpu + gpu only; **no** `ovms-npu`)
- `docker compose --profile {cpu,gpu} config` on Linux host with standalone Compose v2.29.7
- GPU resolved config contains `/dev/dxg` and volume `/usr/lib/wsl:/usr/lib/wsl:ro`; **no** `group_add` / `RENDER_GID`
- `.gitattributes` forces LF for `scripts/*.sh`
- `bash -n` on entrypoint / pull-model; `pull-model.ps1` present (not executed — no Windows host)
- CRLF risk check: scripts are LF on disk in this worktree

## Windows pitfalls noted without a Windows host

- **CRLF:** entrypoint with CRLF fails inside Linux containers — mitigated by `.gitattributes`
- **DrvFs:** clone + `./models` on WSL filesystem, not `C:\...` — README warns
- **Missing `/dev/dxg` on Linux validator:** compose `config` still succeeds (device nodes are not required for config render)
- **Desktop “GPU” checkbox ≠ Intel:** README requires confirming `/dev/dxg` inside WSL
- **Firewall:** allow inbound 8000/9000 on Windows host firewall
- **NPU:** intentionally omitted; LP-W-NPU expect-fail OOS

## What was **not** proven

- Any live `compose up` on Docker Desktop
- Intel GPU via `/dev/dxg` / Level Zero inside WSL2
- Whether `/usr/lib/wsl` bind path is correct on current Docker Desktop (start here; LP-W-GPU-LDLP if libs need `LD_LIBRARY_PATH`)
- Image pull, healthcheck curl/wget presence, auth/prefix/DSF live behavior
