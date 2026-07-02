#!/usr/bin/env bash
# Rewrite the Android export preset's version from a semver string (typically a
# git tag like "v0.0.3"). Godot has no CLI flag to override the export version,
# so we edit export_presets.cfg in place before building.
#
#   versionName  = the semver, e.g. "0.0.3"
#   versionCode  = MAJOR*1000000 + MINOR*1000 + PATCH  (monotonic; minor/patch < 1000)
#
# Usage: set-version.sh <version> [project-dir]
set -euo pipefail

VERSION="${1:?usage: set-version.sh <MAJOR.MINOR.PATCH> [project-dir]}"
PROJECT="${2:-game}"
PRESET="$PROJECT/export_presets.cfg"

semver="${VERSION#v}"     # strip a leading "v"
core="${semver%%-*}"      # drop any -prerelease suffix for the numeric parts
IFS=. read -r major minor patch <<<"$core"
major="${major:-0}"; minor="${minor:-0}"; patch="${patch:-0}"

for part in "$major" "$minor" "$patch"; do
  case "$part" in
    ''|*[!0-9]*) echo "set-version: '$VERSION' is not MAJOR.MINOR.PATCH" >&2; exit 1 ;;
  esac
done
if [ "$minor" -ge 1000 ] || [ "$patch" -ge 1000 ]; then
  echo "set-version: minor/patch must be < 1000 (got $core)" >&2
  exit 1
fi

code=$(( major * 1000000 + minor * 1000 + patch ))

sed -i \
  -e "s|^version/code=.*|version/code=$code|" \
  -e "s|^version/name=.*|version/name=\"$semver\"|" \
  "$PRESET"

echo "set-version: versionName=$semver versionCode=$code"
