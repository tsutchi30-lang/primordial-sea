#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/m1-5/after}"
mkdir -p "$output_dir" build
output_dir="$(cd "$output_dir" && pwd)"
: > build/.gdignore
: > "$output_dir/.gdignore"
export PATH="${PRIMORDIAL_ENV_ROOT:-$repo_root/.tools}/bin:$PATH"
tools/bootstrap.sh
python3 tools/generate_assets.py
if ! timeout --kill-after=10 180 tools/godot.sh --headless --path . --editor --import > "$output_dir/import.log" 2>&1; then
  cat "$output_dir/import.log" >&2
  exit 1
fi
if grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:' "$output_dir/import.log"; then exit 1; fi
source_commit="${PRIMORDIAL_SOURCE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo source-archive)}"
display_runner=()
if [[ -z "${DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || { echo 'CAPTURE_FAIL: DISPLAY or xvfb-run required' >&2; exit 1; }
  display_runner=(xvfb-run -a -s '-screen 0 1920x1080x24')
fi
for resolution in ${CAPTURE_RESOLUTIONS:-1280x720 1920x1080}; do
  log="$output_dir/capture-$resolution.log"
  if ! timeout --kill-after=10 240 "${display_runner[@]}" tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --resolution "$resolution" --script res://tools/capture_visuals.gd -- --output "$output_dir/$resolution" --source-commit "$source_commit" > "$log" 2>&1; then
    cat "$log"; echo "CAPTURE_FAIL: $resolution" >&2; exit 1
  fi
  cat "$log"
  if ! grep -Eq '^CAPTURE_OK ' "$log" || grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:|CAPTURE_FAIL' "$log"; then exit 1; fi
done
python3 tools/capture_contact_sheet.py "$output_dir"
python3 tools/write_evidence_manifest.py "$output_dir"
printf 'VISUALS_OK output=%s (raw image generation; inspect separately)\n' "$output_dir"
