#!/usr/bin/env bash
# Official Godot standard editor + matching desktop export templates. Linux x86_64.
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$repo_root/.godot-version")"
env_root="${PRIMORDIAL_ENV_ROOT:-$repo_root/.tools}"
if [[ "$env_root" != /* ]]; then env_root="$repo_root/$env_root"; fi
asset_base="https://github.com/godotengine/godot-builds/releases/download/$version-stable"
editor_name="Godot_v$version-stable_linux.x86_64"
template_name="Godot_v$version-stable_export_templates.tpz"
template_dir="$env_root/data/godot/export_templates/$version.stable"
editor_path="$env_root/godot/$version/$editor_name"

[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || {
  echo 'bootstrap requires Linux x86_64; use the pinned Godot editor manually elsewhere.' >&2; exit 1;
}
for dependency in curl unzip python3 sha512sum timeout; do
  command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
# Copied from the official release's SHA512-SUMS.txt (confirmed 2026-10-10).
case "$version" in
  4.7.2)
    editor_sha=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
    templates_sha=ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079
    ;;
  *) echo "Unreviewed Godot version: $version. Add the official release hashes explicitly." >&2; exit 1 ;;
esac
mkdir -p "$env_root"/{downloads,bin,cache,config,data} "$env_root/godot/$version" "$template_dir"
export XDG_DATA_HOME="$env_root/data"
export XDG_CONFIG_HOME="$env_root/config"
export XDG_CACHE_HOME="$env_root/cache"

fetch_verified() {
  local filename="$1" checksum="$2" archive="$env_root/downloads/$1"
  if [[ ! -f "$archive" ]]; then
    echo "Downloading $asset_base/$filename"
    if ! curl --fail --location --silent --show-error --retry 2 --connect-timeout 30 --max-time 900 \
      --output "$archive.part" "$asset_base/$filename"; then
      echo "Download failed: host github.com (release assets may redirect to release-assets.githubusercontent.com), asset $filename" >&2
      rm -f -- "$archive.part"
      exit 1
    fi
    mv -- "$archive.part" "$archive"
  fi
  echo "$checksum  $archive" | sha512sum --check --status || {
    echo "Official SHA-512 mismatch: $archive. Remove this cached archive and rerun bootstrap." >&2; exit 1;
  }
}

# A marker is written only after verifying archives, editor version and all templates.
# Repeated invocations avoid downloads and a 1.2 GB archive checksum.
marker="$env_root/godot/$version/.verified-sha512"
ready=false
if [[ -x "$editor_path" && -f "$marker" && -f "$template_dir/version.txt" ]]; then
  if [[ "$(cat "$marker")" == "$editor_sha $templates_sha" && "$(cat "$template_dir/version.txt")" == "$version.stable" ]]; then
    ready=true
    for template in windows_debug_x86_64.exe windows_release_x86_64.exe linux_debug.x86_64 linux_release.x86_64; do
      [[ -s "$template_dir/$template" ]] || ready=false
    done
  fi
fi
if [[ "$ready" != true ]]; then
  fetch_verified "$editor_name.zip" "$editor_sha"
  fetch_verified "$template_name" "$templates_sha"
  unzip -qo "$env_root/downloads/$editor_name.zip" -d "$env_root/godot/$version"
  chmod +x "$editor_path"
  unzip -qjo "$env_root/downloads/$template_name" \
    'templates/version.txt' 'templates/windows_debug_x86_64.exe' 'templates/windows_release_x86_64.exe' \
    'templates/linux_debug.x86_64' 'templates/linux_release.x86_64' -d "$template_dir"
  [[ "$(cat "$template_dir/version.txt")" == "$version.stable" ]] || { echo 'Template version mismatch' >&2; exit 1; }
fi
actual_version="$("$editor_path" --version)"
[[ "$actual_version" == "$version.stable."* ]] || { echo "Editor version mismatch: $actual_version" >&2; exit 1; }
printf '%s %s\n' "$editor_sha" "$templates_sha" > "$marker"
ln -sfn "$editor_path" "$env_root/bin/godot"
ln -sfn godot "$env_root/bin/godot4"
echo "BOOTSTRAP_OK: $actual_version; installation $env_root"
echo "Run: tools/godot.sh --editor --path \"$repo_root\" (set PRIMORDIAL_ENV_ROOT if using a custom installation)"
