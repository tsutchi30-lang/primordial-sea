#!/usr/bin/env bash
# Explicit wrapper: never accidentally use an unrelated Godot on PATH.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_root/.godot-version")"
env_root="${PRIMORDIAL_ENV_ROOT:-$repo_root/.tools}"
if [[ "$env_root" != /* ]]; then env_root="$repo_root/$env_root"; fi
editor_path="$env_root/godot/$version/Godot_v$version-stable_linux.x86_64"
if [[ ! -x "$editor_path" ]]; then
  echo "Pinned Godot missing at $editor_path. Run tools/bootstrap.sh first." >&2; exit 1
fi
export XDG_DATA_HOME="$env_root/data"
export XDG_CONFIG_HOME="$env_root/config"
export XDG_CACHE_HOME="$env_root/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
actual_version="$("$editor_path" --version)"
[[ "$actual_version" == "$version.stable."* ]] || { echo "Editor version mismatch: $actual_version" >&2; exit 1; }
exec "$editor_path" "$@"
