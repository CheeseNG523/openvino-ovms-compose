# Optional host-side helper: run scripts/pull-model.sh inside WSL.
# Prefer cloning this repo on the WSL filesystem (not C:\ DrvFs).
# Usage (from PowerShell, repo root on a WSL path):
#   .\scripts\pull-model.ps1
#   $env:SOURCE_MODEL = "OpenVINO/other-int4-ov"; .\scripts\pull-model.ps1
$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
# Convert Windows path to WSL path when possible; if already under \\wsl$\ use as-is via wsl pwd.
$WslCmd = "cd `"$(wsl wslpath -a `"$RepoRoot`")`" && ./scripts/pull-model.sh"
if ($env:SOURCE_MODEL) {
  $WslCmd = "export SOURCE_MODEL=`"$($env:SOURCE_MODEL)`"; $WslCmd"
}
Write-Host "Invoking via WSL: $WslCmd"
wsl -e bash -lc $WslCmd
