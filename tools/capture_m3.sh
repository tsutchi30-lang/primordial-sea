#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/m3}"
requested_mode="${2:-all}"
case "$requested_mode" in all|visuals|relay|kangaku|core|return|probe) ;; *) echo 'Unknown M3 capture mode' >&2; exit 1 ;; esac
mkdir -p "$output_dir" build
output_dir="$(cd "$output_dir" && pwd)"
: > build/.gdignore
: > "$output_dir/.gdignore"
tools/bootstrap.sh
python3 tools/generate_assets.py
checked() {
  local log="$1" duration="$2" marker="$3"
  shift 3
  if ! timeout --kill-after=10 "$duration" "$@" > "$log" 2>&1; then tail -60 "$log" >&2; return 1; fi
  if grep -En 'SCRIPT ERROR|Parse Error|Failed to load|^ERROR:|M3_(VISUAL|REPLAY)_FAIL' "$log"; then return 1; fi
  if [[ -n "$marker" ]] && ! grep -Eq "^${marker}([[:space:]:]|$)" "$log"; then tail -60 "$log" >&2; return 1; fi
  tail -4 "$log"
}
checked "$output_dir/import.log" 180 '' tools/godot.sh --headless --path . --editor --import
source_commit="${PRIMORDIAL_SOURCE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo source-archive)}"
python3 tools/capture_m2_source.py begin "$output_dir/capture-source-$requested_mode.json"
runner=()
if [[ -z "${DISPLAY:-}" && "$requested_mode" != probe ]]; then
  command -v xvfb-run >/dev/null || { echo 'M3_CAPTURE_FAIL: DISPLAY or xvfb-run required' >&2; exit 1; }
  runner=(xvfb-run -a -s '-screen 0 1920x1080x24')
fi
if [[ "$requested_mode" == all || "$requested_mode" == visuals ]]; then
  mkdir -p "$output_dir/visuals"
  for resolution in ${CAPTURE_RESOLUTIONS:-1280x720}; do
    checked "$output_dir/visuals/capture-$resolution.log" 330 M3_VISUAL_OK "${runner[@]}" tools/godot.sh --path . --rendering-method gl_compatibility --audio-driver Dummy --resolution "$resolution" --script res://tools/capture_m3_visuals.gd -- --output "$output_dir/visuals/$resolution"
  done
  python3 tools/capture_contact_sheet.py "$output_dir/visuals"
  python3 tools/write_evidence_manifest.py "$output_dir/visuals"
fi
modes=()
if [[ "$requested_mode" == all || "$requested_mode" == probe ]]; then modes=(relay kangaku core return)
elif [[ "$requested_mode" != visuals ]]; then modes=("$requested_mode"); fi
for mode in "${modes[@]}"; do
  folder="$output_dir/motion/$mode"
  if [[ "$requested_mode" == probe ]]; then folder="$output_dir/probe/$mode"; fi
  mkdir -p "$folder"
  args=(--path . --rendering-method gl_compatibility --audio-driver Dummy --fixed-fps 24 --script res://tools/capture_m3_replay.gd)
  if [[ "$requested_mode" == probe ]]; then
    checked "$folder/capture.log" 180 M3_REPLAY_OK tools/godot.sh "${args[@]}" --headless -- --mode "$mode" --output "$folder" --source-commit "$source_commit"
  else
    checked "$folder/capture.log" 900 M3_REPLAY_OK "${runner[@]}" tools/godot.sh "${args[@]}" --resolution 1280x720 --disable-vsync --write-movie "$folder/$mode.avi" -- --mode "$mode" --output "$folder" --source-commit "$source_commit"
    timeout --kill-after=10 240 ffmpeg -nostdin -y -loglevel error -i "$folder/$mode.avi" -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p -c:a aac -movflags +faststart "$folder/$mode.mp4"
    ffprobe -v error -show_streams -show_format -of json "$folder/$mode.mp4" > "$folder/video-info.json"
    python3 - "$folder" <<'PY'
import json,sys
from pathlib import Path
from fractions import Fraction
p=Path(sys.argv[1]); info=json.loads((p/'video-info.json').read_text()); replay=json.loads((p/'manifest.json').read_text())
v=next(s for s in info['streams'] if s['codec_type']=='video'); a=next(s for s in info['streams'] if s['codec_type']=='audio')
assert replay['success'] and (v['width'],v['height'])==(1280,720)
assert Fraction(v['avg_frame_rate'])==24
assert replay['seconds']-0.15 <= float(v['duration']) <= replay['seconds']+2
assert float(a['duration']) >= replay['seconds']-0.15
print('M3_ENCODED_VIDEO_OK',p.name,v['duration'],a['codec_name'])
PY
    rm -- "$folder/$mode.avi"
    python3 tools/capture_m2_filmstrip.py "$folder/$mode.mp4" "$folder/frames" "$mode"
  fi
  python3 tools/write_evidence_manifest.py "$folder"
done
mkdir -p "$output_dir/review" "$output_dir/verification"
for doc in M3_IMPLEMENTATION.md M3_ACCEPTANCE.md SAVE_MIGRATION.md PLAYTEST.md QUALITY_BACKLOG.md BUILD_AND_TEST.md PROGRESS.md; do
  if [[ -f "docs/$doc" ]]; then cp "docs/$doc" "$output_dir/review/"; fi
done
for log in build/logs/*.log build/logs/VERIFIED.txt; do
  if [[ -f "$log" ]]; then cp "$log" "$output_dir/verification/"; fi
done
cat > "$output_dir/確認方法_日本語.txt" <<'TXT'
原初の海 M3 — 帰還までの本編資料
visuals/: 720pの22画面。カメラ・進行・環顎姿勢の静止fixtureはmanifestに明記。
motion/relay/: 入口から泳いで見える端末へ、E操作と補給。
motion/kangaku/: 通常の巡回個体へ接近、照準固定後に通常入力で回避、岩柱へ。
motion/core/: 船内へ泳ぎ、カッター解除、E回収、別出口から岩陰へ。
motion/return/: 携行コアを持つポッド前fixtureからE帰投・保管、端末起動、28秒の帰還、調査再開。
各動画は初期配置後に本番Input・酸素・衝突・AIを通す720p/24fpsのオフライン収録。
動画間は別ケースです。長い帰路はroutes/routes-manifest.jsonの本番入力走行で別途確認。
frames/: MP4から元frame index/PTSで抽出した補助一覧。原動画に補間・早回し・色補正なし。
routes/: 480秒タンク・未改良カッター・誘餌とパルス0、補給直前と最小酸素。
ecology/: 6m/10mの横・上下回避、局所感知、実捕食、両出口からの離脱。
capture-source-*.json/evidence.json: 起動元・ソース照合・ファイルSHA256。
生成・画像目視・時系列フレーム目視・連続再生・聴取は別です。確認範囲はreview/M3_ACCEPTANCE.md。
Linux llvmpipeのオフライン収録はWindows実GPUのFPSや操作・音の検収ではありません。
TXT
python3 tools/capture_m2_source.py end "$output_dir/capture-source-$requested_mode.json"
python3 tools/write_evidence_manifest.py "$output_dir"
echo "M3_EVIDENCE_OK output=$output_dir mode=$requested_mode"
