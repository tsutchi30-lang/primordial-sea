#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
# Export always includes the same verified preparation path used by CI.
tools/verify.sh
output_dir="$repo_root/build/windows"
mkdir -p "$output_dir"
rm -f "$output_dir/PrimordialSea.exe" "$output_dir/PrimordialSea.pck" "$output_dir/BUILD_INFO.txt"
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
for doc in VISUAL_REVIEW_M1_5.md ART_DIRECTION.md ASSET_PIPELINE.md; do
  if [[ -f "docs/$doc" ]]; then cp "docs/$doc" "$output_dir/$doc"; fi
done
cp build/logs/VERIFIED.txt "$output_dir/VERIFICATION.txt"
cat >> "$output_dir/VERIFICATION.txt" <<'TXT'
WINDOWS_EXPORT_OK: PE executable and separate PCK verified.
This is an export check, not a Windows device playtest.
TXT
cat > "$output_dir/はじめに.txt" <<'TXT'
原初の海 — 航法復旧編 / M1.5 見た目改善版 / Windows x86_64

展開したフォルダから PrimordialSea.exe を起動してください。
PrimordialSea.pck と licenses フォルダを同じ場所に残してください。
オフラインで動作します。Godot の別途インストールは不要です。

目標: 浅瀬で金属片2個、艇の残骸で航法ユニットを回収し、ポッドで航法を復旧。
本開発版は「航法復旧編」まで。全編の帰還は今後の範囲です。
今回の改善: 浅瀬から東の帆殻獣へ近づき、殻と三本脚を観察し、腹側で並走。

WASD:泳ぐ / Space:上昇 / C:下降 / Shift:加速 / マウス:視点
E:調べる・拾う / 左クリック:道具 / Q:緊急パルス / F:ライト
1〜5・ホイール:道具 / Tab:図鑑・持ち物 / Esc:一時停止・マウス解放

タイトルの「新しく始める」から開始。「続きから」は最後のポッド保存点。
ポッドで補給・保管・保存。水中で終了すると最後の保存点へ戻ります。
保存: %APPDATA%\PrimordialSea\
設定と進行はゲームの保存フォルダ内で別々に管理されます。

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
  echo 'Game: Primordial Sea / 原初の海 航法復旧編'
  echo 'Game version: 0.1.5-m1.5'
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
