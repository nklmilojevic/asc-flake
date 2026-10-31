#!/usr/bin/env bash
set -euo pipefail

SOURCES_FILE="sources.json"
GITHUB_API_URL="https://api.github.com/repos/rorkai/App-Store-Connect-CLI/releases"
RELEASE_BASE_URL="https://github.com/rorkai/App-Store-Connect-CLI/releases/download"

# nix system -> release asset suffix (asc_<version>_<suffix>)
PLATFORMS="
x86_64-linux:linux_amd64
aarch64-linux:linux_arm64
x86_64-darwin:macOS_amd64
aarch64-darwin:macOS_arm64
"

get_latest_stable_version() {
  local headers=(-H "Accept: application/vnd.github+json" -H "User-Agent: asc-flake-updater")

  # Use GITHUB_TOKEN if available
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers+=(-H "Authorization: Bearer $GITHUB_TOKEN")
  fi

  # Upstream tags have no "v" prefix
  curl -sL "${headers[@]}" "$GITHUB_API_URL?per_page=100" | jq -r '
    [.[] | select(.prerelease == false and .draft == false)
         | .tag_name
         | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))]
    | sort_by(split(".") | map(tonumber))
    | reverse
    | first
  '
}

compute_sri_hash() {
  local url="$1"
  nix store prefetch-file "$url" --json 2>/dev/null | jq -r '.hash'
}

# Upstream publishes asc_<version>_checksums.txt; refuse assets that don't match it.
verify_checksum() {
  local checksums="$1" asset="$2" hash="$3"
  local expected actual
  expected=$(awk -v name="$asset" '$2 == name { print $1 }' <<< "$checksums")
  actual=$(nix hash convert --hash-algo sha256 --to base16 "$hash")
  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    echo "Error: checksum mismatch for $asset (expected '$expected', got '$actual')"
    exit 1
  fi
}

main() {
  echo "Checking for asc updates..."

  local current_version
  current_version=$(jq -r '.version' "$SOURCES_FILE")
  echo "Current version: $current_version"

  local latest_version
  latest_version=$(get_latest_stable_version)

  if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
    echo "Error: Failed to get latest version"
    exit 1
  fi

  echo "Latest stable version: $latest_version"

  if [[ "$current_version" == "$latest_version" ]]; then
    echo "Already at latest version, no update needed"
    exit 0
  fi

  echo "Updating from $current_version to $latest_version..."

  local checksums
  checksums=$(curl -sfL "$RELEASE_BASE_URL/${latest_version}/asc_${latest_version}_checksums.txt")

  local platforms_json="{}"

  for entry in $PLATFORMS; do
    local nix_platform="${entry%%:*}"
    local asset="asc_${latest_version}_${entry##*:}"
    local url="$RELEASE_BASE_URL/${latest_version}/${asset}"

    echo "Fetching hash for $nix_platform..."

    local hash
    hash=$(compute_sri_hash "$url")

    if [[ -z "$hash" || "$hash" == "null" ]]; then
      echo "Error: Failed to compute hash for $nix_platform"
      exit 1
    fi

    verify_checksum "$checksums" "$asset" "$hash"
    echo "  $nix_platform: $hash"

    platforms_json=$(echo "$platforms_json" | jq \
      --arg platform "$nix_platform" \
      --arg url "$url" \
      --arg hash "$hash" \
      '. + {($platform): {"url": $url, "hash": $hash}}')
  done

  jq -n \
    --arg version "$latest_version" \
    --argjson platforms "$platforms_json" \
    '{"version": $version, "platforms": $platforms}' > "$SOURCES_FILE"

  echo "Successfully updated sources.json to version $latest_version"
}

main "$@"
