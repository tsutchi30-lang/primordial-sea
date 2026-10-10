#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/screenshots}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
: > "$output_dir/.gdignore"

tools/bootstrap.sh
python3 tools/generate_assets.py
if ! timeout --kill-after=10 180 tools/godot.sh --headless --path . --editor --import > "$output_dir/import.log" 2>&1; then
  cat "$output_dir/import.log" >&2
  printf 'CAPTURE_FAIL: import or import timeout; log=%s/import.log\n' "$output_dir" >&2
  exit 1
fi
if grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:' "$output_dir/import.log"; then
  exit 1
fi

# Requires a real X11 display, or Xvfb with OpenGL software rendering.
# Headless viewports are intentionally rejected by the capture script.
display_runner=()
if [[ -z "${DISPLAY:-}" ]]; then
  if command -v xvfb-run >/dev/null 2>&1; then
    display_runner=(xvfb-run -a -s '-screen 0 1920x1080x24')
  else
    printf '%s\n' 'CAPTURE_FAIL: DISPLAY or xvfb-run is required. Install Xvfb or run from a Linux desktop.' >&2
    exit 1
  fi
fi

for resolution in 1280x720 1920x1080; do
  log="$output_dir/capture-$resolution.log"
  if ! timeout --kill-after=10 180 "${display_runner[@]}" tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution "$resolution" --script res://tools/capture_visuals.gd -- --output "$output_dir/$resolution" > "$log" 2>&1; then
    cat "$log"
    printf 'CAPTURE_FAIL: render/timeout at %s\n' "$resolution" >&2
    exit 1
  fi
  cat "$log"
  if ! grep -Eq '^CAPTURE_OK ' "$log" || grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:|CAPTURE_FAIL' "$log"; then
    exit 1
  fi
done
printf 'VISUALS_OK output=%s (image generation; inspect images separately)\n' "$output_dir"
