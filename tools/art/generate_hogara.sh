#!/usr/bin/env bash
# Art authoring only. Normal import/export uses the versioned GLB and PNG assets.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
blender_bin="${PRIMORDIAL_BLENDER_BIN:-blender}"
version="$("$blender_bin" --version | head -n 1)"
if [[ "$version" != "Blender 4.3.2" ]]; then
  printf 'HOGARA_ASSET_FAIL: expected Blender 4.3.2, got %s\n' "$version" >&2
  exit 1
fi
mkdir -p build/art
log="build/art/hogara-generation.log"
timeout 180 "$blender_bin" --background --factory-startup --python tools/art/generate_hogara.py -- "$@" > "$log" 2>&1
if ! rg -q '^HOGARA_ASSET_OK ' "$log" || rg -n 'Traceback|Error:|Warning:.*tangent' "$log"; then
  cat "$log"
  exit 1
fi
python3 tools/art/inspect_hogara_glb.py
printf 'HOGARA_AUTHORING_OK log=%s\n' "$log"
