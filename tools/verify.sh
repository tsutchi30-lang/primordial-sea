#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
mkdir -p build/logs build/m2/routes
touch build/.gdignore
rm -f build/logs/VERIFIED.txt
for stage in import smoke hogara-gait save-migration m2-flow m2-interface plains-ecology graveyard-ecology palaeo-ecology m2-world pod-route m2-routes m3-save m3-flow m3-ecology m3-routes export; do
  rm -f "build/logs/$stage.log"
done
rm -f build/m2/routes/routes-manifest.json build/m2/routes/evidence.json
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
run_test() {
  local stage="$1" duration="$2" script="$3" marker="$4"
  run_checked "$stage" "$duration" tools/godot.sh --headless --path "$repo_root" --script "$script"
  if ! grep -Eq "^${marker}([[:space:]:]|$)" "build/logs/$stage.log"; then
    echo "VERIFY_FAILED: $stage did not emit $marker" >&2; exit 1
  fi
}
run_test smoke "${VERIFY_TIMEOUT_SECONDS:-180}" res://tests/smoke_test.gd SMOKE_OK
run_test hogara-gait 150 res://tests/hogara_gait_test.gd HOGARA_GAIT_OK
run_test save-migration 60 res://tests/save_migration_test.gd SAVE_MIGRATION_OK
run_test m2-flow 180 res://tests/m2_flow_test.gd M2_FLOW_OK
run_test m2-interface 120 res://tests/m2_interface_test.gd M2_INTERFACE_OK
run_test plains-ecology 90 res://tests/plains_ecology_test.gd PLAINS_ECOLOGY_OK
run_test graveyard-ecology 120 res://tests/graveyard_ecology_test.gd GRAVEYARD_ECOLOGY_OK
run_test palaeo-ecology 90 res://tests/palaeo_ecology_test.gd PALAEO_OK
run_test m2-world 120 res://tests/m2_world_test.gd M2_WORLD_OK
run_test m3-save 60 res://tests/m3_save_test.gd M3_SAVE_OK
run_test m3-flow 180 res://tests/m3_flow_test.gd M3_FLOW_OK
run_checked m3-ecology 240 tools/godot.sh --headless --path "$repo_root" --fixed-fps 60 --script res://tests/m3_ecology_test.gd
if ! grep -Eq '^M3_ECOLOGY_OK ' build/logs/m3-ecology.log; then exit 1; fi
run_checked m3-routes 600 tools/godot.sh --headless --path "$repo_root" --fixed-fps 60 --script res://tests/m3_routes_test.gd
if ! grep -Eq '^M3_ROUTES_OK ' build/logs/m3-routes.log; then exit 1; fi
source_commit="${PRIMORDIAL_SOURCE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || echo source-archive)}"
run_checked pod-route 120 tools/godot.sh --headless --path "$repo_root" --fixed-fps 60 --script res://tools/capture_encounter.gd -- --mode pod-route --output "$repo_root/build/m1-5/reach" --source-commit "$source_commit"
if ! grep -Eq '^REPLAY_OK ' build/logs/pod-route.log; then
  echo 'VERIFY_FAILED: pod-to-encounter input replay did not pass' >&2; exit 1
fi
python3 tools/write_evidence_manifest.py "$repo_root/build/m1-5/reach"
run_checked m2-routes 600 tools/godot.sh --headless --path "$repo_root" --fixed-fps 60 --script res://tests/m2_routes_test.gd -- --output "$repo_root/build/m2/routes" --source-commit "$source_commit"
if ! grep -Eq '^M2_ROUTES_OK ' build/logs/m2-routes.log; then
  echo 'VERIFY_FAILED: M2 input routes did not pass' >&2; exit 1
fi
python3 tools/write_evidence_manifest.py "$repo_root/build/m2/routes"
{
  echo "IMPORT_M1_M2_M3_SAVE_FLOW_ECOLOGY_AND_ROUTES_OK"
  date -u '+UTC=%Y-%m-%dT%H:%M:%SZ'
  tools/godot.sh --version
  echo 'Windows hardware/audio/manual controls remain separate checks; see docs/PLAYTEST.md.'
} > build/logs/VERIFIED.txt
echo 'VERIFY_OK: import, M1 gameplay/gait, M2/M3 saves/flow/ecology and live input routes; logs in build/logs/'
