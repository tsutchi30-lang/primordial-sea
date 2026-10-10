#!/usr/bin/env bash
# M2 evidence only; optional M1.5 before/after comparisons stay a separate tool.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/m2}"
requested_mode="${2:-all}"
case "$requested_mode" in all|visuals|plains|graveyard|metrics|probe) ;; *) echo "Unknown M2 capture mode: $requested_mode" >&2; exit 1 ;; esac
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
python3 tools/capture_m2_source.py begin "$output_dir/capture-source-$requested_mode.json"
display_runner=()
if [[ -z "${DISPLAY:-}" && "$requested_mode" != probe ]]; then
  command -v xvfb-run >/dev/null || { echo 'M2_CAPTURE_FAIL: DISPLAY or xvfb-run required' >&2; exit 1; }
  display_runner=(xvfb-run -a -s '-screen 0 1920x1080x24')
fi
checked() {
  local log="$1" duration="$2" marker="$3"
  shift 3
  if ! timeout --kill-after=10 "$duration" "$@" > "$log" 2>&1; then tail -80 "$log" >&2; echo "M2_CAPTURE_FAIL: $log" >&2; return 1; fi
  if ! grep -Eq "^${marker}([[:space:]:]|$)" "$log" || grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:|M2_(CAPTURE|REPLAY)_FAIL' "$log"; then tail -80 "$log" >&2; return 1; fi
  tail -6 "$log"
}
if [[ "$requested_mode" == all || "$requested_mode" == visuals ]]; then
  mkdir -p "$output_dir/visuals"
  for resolution in ${CAPTURE_RESOLUTIONS:-1280x720 1920x1080}; do
    rm -f "$output_dir/visuals/$resolution/"S*.png "$output_dir/visuals/$resolution/manifest.json"
    checked "$output_dir/visuals/capture-$resolution.log" 330 M2_CAPTURE_OK "${display_runner[@]}" tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 60 --resolution "$resolution" --script res://tools/capture_m2_visuals.gd -- --output "$output_dir/visuals/$resolution" --source-commit "$source_commit"
  done
  python3 tools/capture_contact_sheet.py "$output_dir/visuals"
  python3 tools/write_evidence_manifest.py "$output_dir/visuals"
fi
modes=()
if [[ "$requested_mode" == all ]]; then modes=(plains graveyard metrics)
elif [[ "$requested_mode" == probe ]]; then modes=(plains graveyard)
elif [[ "$requested_mode" != visuals ]]; then modes=("$requested_mode")
fi
motion_dir="$output_dir/motion"
if [[ "$requested_mode" == probe ]]; then motion_dir="$output_dir/probe"; fi
mkdir -p "$motion_dir"
for mode in "${modes[@]}"; do
  rm -f "$motion_dir/$mode-manifest.json" "$motion_dir/$mode-video-info.json" "$motion_dir/$mode.mp4" "$motion_dir/$mode.avi"
  python3 - "$motion_dir/frames-$mode" <<'CLEAN_PY'
from pathlib import Path
import shutil, sys
p = Path(sys.argv[1])
if p.exists(): shutil.rmtree(p)
CLEAN_PY
  args=(--path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/capture_m2_replay.gd)
  runner=("${display_runner[@]}")
  if [[ "$requested_mode" == probe ]]; then
    runner=()
    args+=(--headless --fixed-fps 24)
  elif [[ "$mode" == metrics ]]; then
    args+=(--resolution 1920x1080 --disable-vsync)
  else
    command -v ffmpeg >/dev/null || { echo 'M2_CAPTURE_FAIL: ffmpeg required' >&2; exit 1; }
    args+=(--resolution 1280x720 --write-movie "$motion_dir/$mode.avi" --fixed-fps 24 --disable-vsync)
  fi
  checked "$motion_dir/$mode.log" 1140 M2_REPLAY_OK "${runner[@]}" tools/godot.sh "${args[@]}" -- --mode "$mode" --output "$motion_dir" --source-commit "$source_commit"
  if [[ "$mode" != metrics && "$requested_mode" != probe ]]; then
    timeout --kill-after=10 240 ffmpeg -nostdin -y -loglevel error -i "$motion_dir/$mode.avi" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -movflags +faststart "$motion_dir/$mode.mp4"
    ffprobe -v error -show_streams -show_format -of json "$motion_dir/$mode.mp4" > "$motion_dir/$mode-video-info.json"
    python3 - "$motion_dir/$mode-video-info.json" <<'VIDEO_PY'
import json, sys
from fractions import Fraction
info = json.load(open(sys.argv[1]))
video = next(s for s in info['streams'] if s['codec_type'] == 'video')
audio = next(s for s in info['streams'] if s['codec_type'] == 'audio')
assert (video['width'], video['height']) == (1280, 720), 'Wrong movie resolution'
assert Fraction(video['avg_frame_rate']) == 24, 'Wrong frame rate'
assert 50 <= float(video['duration']) < 52, 'Incomplete movie'
assert float(audio['duration']) >= 50, 'Incomplete audio track'
print(f'M2_ENCODED_VIDEO_OK frames={video["nb_frames"]} duration={video["duration"]} audio={audio["codec_name"]}')
VIDEO_PY
    rm -- "$motion_dir/$mode.avi"
    python3 tools/capture_m2_filmstrip.py "$motion_dir/$mode.mp4" "$motion_dir/frames-$mode" "$mode"
  fi
done
python3 tools/write_evidence_manifest.py "$motion_dir"
mkdir -p "$output_dir/review" "$output_dir/verification"
for doc in M2_IMPLEMENTATION.md M2_ACCEPTANCE.md SAVE_MIGRATION.md PLAYTEST.md QUALITY_BACKLOG.md BUILD_AND_TEST.md PROGRESS.md; do
  if [[ -f "docs/$doc" ]]; then cp "docs/$doc" "$output_dir/review/"; fi
done
for log in build/logs/*.log build/logs/VERIFIED.txt; do
  if [[ -f "$log" ]]; then cp "$log" "$output_dir/verification/"; fi
done
cat > "$output_dir/確認方法_日本語.txt" <<'TXT'
原初の海 M2 — 新海域・生態利用・帰路の確認資料

visuals/: 720p/1080pの本編。静止カメラとM1完了済みの隔離保存fixture。
通常の「新しく始める」はM1からです。完了画面用の部品保管fixtureはmanifestに明記。
motion/plains.mp4: 自然採餌の切れ目、通常Inputで通過、粘糸へ窓喰いを誘導。
motion/graveyard.mp4: Shiftで壺を刺激、予兆と伝播、六面這いの移動、殻を通過。
両動画は720p/24fpsのオフライン収録。補間・早回し・色補正なし。
始点配置以後は本編Input・衝突・酸素・AIが動き、毎フレーム座標を設定しません。
motion/frames-*/: MP4から正確な元frame index/PTSで抽出した補助一覧。
motion/metrics-manifest.json: 独立した1080pの実時間計測（Windows GPUとは別）。
routes/routes-manifest.json: 基本タンク480秒・未改良カッターの本番Input経路。
各区間の出発時、補給直前、最小酸素を読みます。補給後の100%は余裕に数えません。
verification/: import・回帰・旧保存移行・生態・経路・exportのログ。
review/: M2の受入、旧保存の引継ぎ、短いWindows確認手順と未確認事項。
capture-source-*.json/evidence.json: 起動時ソースと実装head/検証checkout、各ファイルSHA256。

画像生成と目視、フレーム列の目視と連続動画再生、音声トラックと聴取は別です。
Windows実機の起動・マウス・音・操作感は別途 PLAYTEST.md で確認してください。
TXT
python3 tools/capture_m2_source.py end "$output_dir/capture-source-$requested_mode.json"
python3 tools/write_evidence_manifest.py "$output_dir"
echo "M2_EVIDENCE_OK output=$output_dir mode=$requested_mode"
