#!/usr/bin/env bash
# Recreate the actual M1 baseline from Git; never commit generated evidence PNGs.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
output_dir="${1:-build/m1-5}"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
: > "$output_dir/.gdignore"
baseline_sha=7a2375487f39cdb17356c795cb7a6a8659b622ba
if ! git cat-file -e "$baseline_sha^{commit}"; then
  echo "BASELINE_FAIL: required commit $baseline_sha absent; fetch complete repository history." >&2
  exit 1
fi
export PRIMORDIAL_ENV_ROOT="${PRIMORDIAL_ENV_ROOT:-$repo_root/.tools}"
baseline_dir="$(mktemp -d /tmp/primordial-m1-baseline.XXXXXX)"
trap 'rm -rf -- "$baseline_dir"' EXIT
git archive "$baseline_sha" | tar -x -C "$baseline_dir"
# Copy only the comparison harness; all baseline game code and assets stay at M1.
cp tools/capture_visuals.gd tools/capture_visuals.sh tools/capture_contact_sheet.py tools/write_evidence_manifest.py "$baseline_dir/tools/"
(
  cd "$baseline_dir"
  PRIMORDIAL_SOURCE_COMMIT="$baseline_sha" PRIMORDIAL_BUILD_COMMIT="$baseline_sha" tools/capture_visuals.sh "$output_dir/before-standard"
)
tools/capture_visuals.sh "$output_dir/after"
python3 - "$output_dir" <<'PAIR_PY'
from pathlib import Path
import json, sys
root = Path(sys.argv[1])
checked=[]
for resolution in ('1280x720', '1920x1080'):
    before=json.loads((root/'before-standard'/resolution/'manifest.json').read_text())
    after=json.loads((root/'after'/resolution/'manifest.json').read_text())
    for key in ('seed', 'world_seed', 'engine', 'renderer', 'device', 'os'):
        assert before[key] == after[key], f'{resolution}: {key} differs'
    images={item['id']:item for item in before['images']}
    assert set(images) == {item['id'] for item in after['images']}
    for item in after['images']:
        previous=images[item['id']]
        for key in ('width','height','camera_position','look_at','fov','light_on','low_particles','hogara_position','hogara_rotation','hogara_state'):
            assert previous[key] == item[key], f"{resolution}/{item['id']}: {key} differs"
        checked.append(f"{resolution}/{item['id']}")
(root/'comparison-check.json').write_text(json.dumps({'matched_fixture_images':checked,'scope':'Camera, FOV, resolution, light, particles, seed, renderer, engine and root creature pose match. New articulated canopy and limb poses remain production-derived.'},indent=2)+'\n')
print(f'COMPARISON_CONDITIONS_OK images={len(checked)}')
PAIR_PY
tools/capture_encounter.sh "$output_dir/motion"
mkdir -p "$output_dir/review"
for doc in VISUAL_REVIEW_M1_5.md ART_DIRECTION.md ASSET_PIPELINE.md PLAYTEST.md BUILD_AND_TEST.md PROGRESS.md; do
  test -f "docs/$doc" && cp "docs/$doc" "$output_dir/review/"
done
cat > "$output_dir/確認方法_日本語.txt" <<'TXT'
原初の海 M1.5 — 実ゲーム描画の比較資料

before-standard/: 固定M1 commit 7a23754を再描画した改善前。
after/: 改善後。同じカメラ・FOV80・seed・ライトで比較。
各画像フォルダのmanifest.jsonに個別撮影条件を記録しています。
S08だけは帆の背後へ捕食者を置いた透明面重なりの検査配置です。

motion/encounter.mp4: 接近、全身、近景、腹側へ入場・並走・退出。
motion/gait.mp4: 足元、休息予兆、休息と再始動。
720p/24fpsのオフライン収録で、実時間の24fps達成を意味しません。
MP4に補間・早回し・色補正を行っていません。
frames-*/: 上記MP4から取り出した時刻付きの補助フレーム列。

pod-route-manifest.json: ポッドから実際にInputで泳いだ到達記録。
metrics-manifest.json: 独立した1080pの実時間計測。Linuxの描画環境。
evidence.json: 元ソース、ビルドcommit、各ファイルのハッシュ。
review/: 実装・目視・操作・聴取を区別したレビューと実機手順。

画像と動画の生成成功は、目視・動画再生・音の聴取の完了を意味しません。
Windows実機のマウス・音・操作感は別の確認項目です。
TXT
python3 tools/write_evidence_manifest.py "$output_dir"
echo "COMPARISON_OK output=$output_dir baseline=$baseline_sha"
