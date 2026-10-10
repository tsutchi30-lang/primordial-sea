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
{
  echo "IMPORT_AND_SMOKE_OK"
  date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
  tools/godot.sh --version
  echo 'Windows hardware/audio/manual controls remain separate checks; see docs/PLAYTEST.md.'
} > build/logs/VERIFIED.txt
echo 'VERIFY_OK: import and gameplay smoke; logs in build/logs/'
