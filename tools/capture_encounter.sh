#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/m1-5/motion}"
requested_mode="${2:-all}"
mkdir -p "$output_dir" build
output_dir="$(cd "$output_dir" && pwd)"
: > build/.gdignore
: > "$output_dir/.gdignore"
export PATH="${PRIMORDIAL_ENV_ROOT:-$repo_root/.tools}/bin:$PATH"
tools/bootstrap.sh
python3 tools/generate_assets.py
if ! timeout --kill-after=10 180 tools/godot.sh --headless --path . --editor --import > "$output_dir/import.log" 2>&1; then cat "$output_dir/import.log" >&2; exit 1; fi
if grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:' "$output_dir/import.log"; then exit 1; fi
source_commit="${PRIMORDIAL_SOURCE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo source-archive)}"
display_runner=()
if [[ -z "${DISPLAY:-}" && "$requested_mode" != pod-route ]]; then
  command -v xvfb-run >/dev/null || { echo 'REPLAY_FAIL: DISPLAY or xvfb-run required' >&2; exit 1; }
  display_runner=(xvfb-run -a -s '-screen 0 1920x1080x24')
fi
modes=()
if [[ "$requested_mode" == all ]]; then modes=(pod-route encounter gait metrics); else modes=("$requested_mode"); fi
for mode in "${modes[@]}"; do
  args=(--path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_encounter.gd)
  runner=("${display_runner[@]}")
  if [[ "$mode" == pod-route ]]; then
    runner=()
    args+=(--headless --fixed-fps 60)
  elif [[ "$mode" == metrics ]]; then
    args+=(--resolution 1920x1080 --disable-vsync)
  elif [[ "$mode" == encounter || "$mode" == gait ]]; then
    command -v ffmpeg >/dev/null || { echo 'REPLAY_FAIL: ffmpeg required' >&2; exit 1; }
    args+=(--resolution 1280x720 --write-movie "$output_dir/$mode.avi" --fixed-fps 24 --disable-vsync)
  else
    echo "Unknown replay mode: $mode" >&2; exit 1
  fi
  log="$output_dir/$mode.log"
  if ! timeout --kill-after=10 960 "${runner[@]}" tools/godot.sh "${args[@]}" -- --mode "$mode" --output "$output_dir" --source-commit "$source_commit" > "$log" 2>&1; then
    tail -60 "$log" >&2; echo "REPLAY_FAIL: $mode / $log" >&2; exit 1
  fi
  if ! grep -Eq '^REPLAY_OK ' "$log" || grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:|REPLAY_FAIL' "$log"; then
    tail -60 "$log" >&2; exit 1
  fi
  tail -6 "$log"
  if [[ "$mode" == encounter || "$mode" == gait ]]; then
    timeout --kill-after=10 240 ffmpeg -nostdin -y -loglevel error -i "$output_dir/$mode.avi" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -movflags +faststart "$output_dir/$mode.mp4"
    test -s "$output_dir/$mode.mp4"
    ffprobe -v error -show_streams -show_format -of json "$output_dir/$mode.mp4" > "$output_dir/$mode-video-info.json"
    python3 - "$output_dir/$mode-video-info.json" "$mode" <<'VIDEO_PY'
import json, sys
from fractions import Fraction
info = json.load(open(sys.argv[1]))
video = next(stream for stream in info['streams'] if stream['codec_type'] == 'video')
audio = next(stream for stream in info['streams'] if stream['codec_type'] == 'audio')
expected_seconds = 44 if sys.argv[2] == 'encounter' else 46
assert (video['width'], video['height']) == (1280, 720), 'Wrong video resolution'
assert Fraction(video['avg_frame_rate']) == 24, 'Wrong video frame rate'
assert expected_seconds <= float(video['duration']) < expected_seconds + 2, 'Incomplete or unexpectedly long replay'
assert float(audio['duration']) >= expected_seconds, 'Incomplete audio track'
print(f"ENCODED_VIDEO_OK mode={sys.argv[2]} frames={video['nb_frames']} duration={video['duration']} audio={audio['codec_name']}")
VIDEO_PY
    rm -- "$output_dir/$mode.avi"
    python3 tools/capture_filmstrip.py "$output_dir/$mode.mp4" "$output_dir/frames-$mode" "$mode"
  fi
done
python3 tools/write_evidence_manifest.py "$output_dir"
echo "MOTION_OK output=$output_dir (offline clips and separate realtime metrics; Windows input/audio untested)"
