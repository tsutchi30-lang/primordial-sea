#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
mkdir -p build/logs
touch build/.gdignore
rm -f build/logs/VERIFIED.txt
tools/bootstrap.sh
python3 tools/generate_assets.py

run_checked() {
  local stage="$1" duration="$2"
  shift 2
  echo "VERIFY: $stage (timeout $duration seconds)"
  if timeout --signal=TERM --kill-after=10 "$duration" "$@" >"build/logs/$stage.log" 2>&1; then
    cat "build/logs/$stage.log"
  else
    local status=$?
    cat "build/logs/$stage.log" >&2
    echo "VERIFY_FAILED: $stage exit=$status (124 means timeout); log build/logs/$stage.log" >&2
    exit "$status"
  fi
  if grep -En 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:|Assertion failed' "build/logs/$stage.log"; then
    echo "VERIFY_FAILED: engine error in $stage log" >&2; exit 1
  fi
}
run_checked import 180 tools/godot.sh --headless --path "$repo_root" --editor --import
run_checked smoke "${VERIFY_TIMEOUT_SECONDS:-180}" tools/godot.sh --headless --path "$repo_root" --script res://tests/smoke_test.gd
if ! grep -Eq '^SMOKE_OK([[:space:]:]|$)' build/logs/smoke.log; then
  echo 'VERIFY_FAILED: smoke test did not emit SMOKE_OK' >&2; exit 1
fi
run_checked hogara-gait 150 tools/godot.sh --headless --path "$repo_root" --script res://tests/hogara_gait_test.gd
if ! grep -Eq '^HOGARA_GAIT_OK ' build/logs/hogara-gait.log; then
  echo 'VERIFY_FAILED: articulated gait and shelter checks did not pass' >&2; exit 1
fi
source_commit="${PRIMORDIAL_SOURCE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo source-archive)}"
run_checked pod-route 120 tools/godot.sh --headless --path "$repo_root" --fixed-fps 60 --script res://tools/capture_encounter.gd -- --mode pod-route --output "$repo_root/build/m1-5/reach" --source-commit "$source_commit"
if ! grep -Eq '^REPLAY_OK ' build/logs/pod-route.log; then
  echo 'VERIFY_FAILED: pod-to-encounter input replay did not pass' >&2; exit 1
fi
python3 tools/write_evidence_manifest.py "$repo_root/build/m1-5/reach"
{
  echo "IMPORT_SMOKE_GAIT_AND_POD_ROUTE_OK"
  date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
  tools/godot.sh --version
  echo 'Windows hardware/audio/manual controls remain separate checks; see docs/PLAYTEST.md.'
} > build/logs/VERIFIED.txt
echo 'VERIFY_OK: import, gameplay smoke, articulated gait and live pod-to-encounter input replay; logs in build/logs/'
