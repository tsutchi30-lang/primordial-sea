#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# Export always includes the same verified preparation path used by CI.
tools/verify.sh
output_dir="$repo_root/build/windows"
mkdir -p "$output_dir"
rm -f "$output_dir/PrimordialSea.exe" "$output_dir/PrimordialSea.pck" "$output_dir/BUILD_INFO.txt"
# Remove only generated M1.5 package notes that would misidentify a new M3 export.
rm -f "$output_dir/REVIEW_DOCS_INFO.json" "$output_dir/VISUAL_REVIEW_M1_5.md"
if timeout --signal=TERM --kill-after=10 240 tools/godot.sh --headless --path "$repo_root" \
  --export-release 'Windows Desktop' "$output_dir/PrimordialSea.exe" > build/logs/export.log 2>&1; then
  cat build/logs/export.log
else
  status=$?
  cat build/logs/export.log >&2
  echo "EXPORT_FAILED: exit=$status (124 means timeout); log build/logs/export.log" >&2
  exit "$status"
fi
if grep -En 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:|Assertion failed' build/logs/export.log; then
  echo 'EXPORT_FAILED: engine error in export log' >&2; exit 1
fi
python3 - "$output_dir" <<'PY'
from pathlib import Path
import struct
import sys
folder = Path(sys.argv[1])
exe, pck = folder / 'PrimordialSea.exe', folder / 'PrimordialSea.pck'
assert exe.is_file() and exe.stat().st_size > 1_000_000, 'Missing Windows executable'
assert exe.read_bytes()[:2] == b'MZ', 'Executable has no Windows PE signature'
header = exe.read_bytes()
pe_offset = struct.unpack_from('<I', header, 0x3c)[0]
assert header[pe_offset:pe_offset + 4] == b'PE\0\0', 'Invalid PE header'
assert struct.unpack_from('<H', header, pe_offset + 4)[0] == 0x8664, 'Expected Windows AMD64 executable'
assert pck.is_file() and pck.stat().st_size > 1_000_000, 'Missing PCK data'
assert pck.read_bytes()[:4] == b'GDPC', 'Invalid Godot PCK header'
PY
mkdir -p "$output_dir/licenses"
cp assets/licenses/*.txt "$output_dir/licenses/"
cp docs/PLAYTEST.md "$output_dir/PLAYTEST_日本語.md"
for doc in M3_IMPLEMENTATION.md M3_ACCEPTANCE.md M2_IMPLEMENTATION.md M2_ACCEPTANCE.md SAVE_MIGRATION.md QUALITY_BACKLOG.md BUILD_AND_TEST.md PROGRESS.md ART_DIRECTION.md ASSET_PIPELINE.md; do
  if [[ -f "docs/$doc" ]]; then cp "docs/$doc" "$output_dir/$doc"; fi
done
cp build/logs/VERIFIED.txt "$output_dir/VERIFICATION.txt"
cat >> "$output_dir/VERIFICATION.txt" <<'TXT'
WINDOWS_EXPORT_OK: PE executable and separate PCK verified.
This is an export check, not a Windows device playtest.
TXT
cat > "$output_dir/はじめに.txt" <<'TXT'
原初の海 — 最終帰還編 / M3 / Windows x86_64

展開したフォルダから PrimordialSea.exe を起動してください。
PrimordialSea.pck と licenses フォルダを同じ場所に残してください。
オフラインで動作します。Godot の別途インストールは不要です。

目標: 浅瀬で金属片2個、艇の残骸で航法ユニットを回収し、ポッドで航法を復旧。
航法復旧後: 回廊の先の白濁の平原と殻の墓場で、2点の精密部品を回収。
粘糸と捕食者、共鳴壺と六面這いの習性を読み、中継で補給してポッドへ帰投。
制振フレームと位相調整器を保管し、端末で装置を安定化します。
安定化後は殻の墓場の先「環状の裂け目」へ。棚から環顎の予兆と流れを観察。
沈没調査艇の固定具をカッターで切り、Eで帰還コアを回収します。
別出口と岩柱を使って離脱し、中継で補給、ポッドへ持ち帰って保管。
端末の「帰還装置を起動」で最終帰還。達成後も同じ海で調査を続けられます。

WASD:泳ぐ / Space:上昇 / C:下降 / Shift:加速 / マウス:視点
E:調べる・拾う / 左クリック:道具 / Q:緊急パルス / F:ライト
1〜5・ホイール:道具 / Tab:図鑑・持ち物 / Esc:一時停止・マウス解放

タイトルの「新しく始める」から開始。「続きから」は最後のポッド保存点。
ポッドで補給・保管・保存。水中で終了すると最後の保存点へ戻ります。
保存: %APPDATA%\PrimordialSea\
設定と進行はゲームの保存フォルダ内で別々に管理されます。
M1/M1.5の保存は「続きから」で読み、航法復旧済みならM2の目標へ進めます。
旧schema 1/2は初回schema 3保存前に原文退避します。詳しくは SAVE_MIGRATION.md。
既存進行を続ける場合「新しく始める」を選ばないでください。
中継は酸素とスーツの補給のみ。携行品の保管・保存はポッドで行います。

日本語表示・マウス・Alt+Tab・音のWindows実機確認手順は PLAYTEST_日本語.md。
確認範囲は VERIFICATION.txt、エンジンとソース情報は BUILD_INFO.txt。
exeのコード署名はありません。本版は開発用です。
TXT
commit=source-archive
source_state='unknown (source archive without Git metadata)'
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commit="$(git rev-parse HEAD)"
  dirty="$(git status --porcelain --untracked-files=normal)"
  if [[ -z "$dirty" ]]; then source_state=clean; else source_state='has local changes (development build)'; fi
fi
{
  echo 'Game: Primordial Sea / 原初の海 最終帰還編'
  printf 'Game version: %s\n' "$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
  printf 'Godot: %s\n' "$(tools/godot.sh --version)"
  printf 'Implementation branch head: %s\n' "${PRIMORDIAL_SOURCE_COMMIT:-$commit}"
  printf 'Build checkout commit (may be PR merge commit): %s\n' "$commit"
  printf 'CI event: %s\n' "${GITHUB_EVENT_NAME:-local}"
  printf 'Source tree: %s\n' "$source_state"
  date -u '+Built UTC: %Y-%m-%dT%H:%M:%SZ'
  echo 'Target: Windows x86_64 / Compatibility renderer / unsigned release export'
  echo 'Build command: tools/export_windows.sh'
} > "$output_dir/BUILD_INFO.txt"
(cd "$output_dir" && sha256sum PrimordialSea.exe PrimordialSea.pck > SHA256SUMS.txt)
echo "WINDOWS_EXPORT_OK: $output_dir"
