#!/usr/bin/env bash
# Build a signed release Android App Bundle (.aab) with Godot's Gradle build.
#
# Unlike the sandboxed APK build (`nix build .#apk-release`), an AAB requires
# Godot's Gradle build, which downloads dependencies at build time. That can't
# run inside the pure Nix sandbox, so this script is meant to run in `nix develop`
# (network available) — in CI, or locally for testing.
#
# Signing uses Godot's release-keystore environment variables, so the key is only
# ever a file on the (ephemeral) runner, never written into export_presets.cfg.
#
# Required environment (the dev shell provides ANDROID_HOME / JAVA_HOME):
#   RELEASE_KEYSTORE           path to the release keystore file
#   ANDROID_KEY_ALIAS          key alias inside the keystore
#   ANDROID_KEYSTORE_PASSWORD  keystore (store) password
#   ANDROID_KEY_PASSWORD       key password for the alias
# Optional:
#   PROJECT   Godot project dir (default: game)
#   OUT_AAB   output path       (default: $PWD/yarbell.aab)
set -euo pipefail

PROJECT="${PROJECT:-game}"
OUT_AAB="${OUT_AAB:-$PWD/yarbell.aab}"

: "${ANDROID_HOME:?set by the dev shell}"
: "${JAVA_HOME:?set by the dev shell}"
: "${RELEASE_KEYSTORE:?path to the release keystore}"
: "${ANDROID_KEY_ALIAS:?key alias}"
: "${ANDROID_KEYSTORE_PASSWORD:?keystore password}"
: "${ANDROID_KEY_PASSWORD:?key password}"

# AGP resolves compileSdk 37 to the literal package id "platforms;android-37",
# but nixpkgs installs the platform as android-37.0 (Google's minor-versioned
# artifact) with a package.xml to match — and the SDK sits in the read-only
# Nix store, so Gradle can't fix the mismatch itself. Present a writable
# overlay SDK: every top-level entry symlinked through, plus each
# minor-versioned platform exposed under its major-only name as a
# symlink-tree copy with package.xml/source.properties rewritten to api 37.
SDK_OVERLAY="$(mktemp -d)"
mkdir -p "$SDK_OVERLAY/platforms"
for entry in "$ANDROID_HOME"/*; do
  name="$(basename "$entry")"
  [ "$name" = "platforms" ] || ln -s "$entry" "$SDK_OVERLAY/$name"
done
for platform in "$ANDROID_HOME"/platforms/android-*; do
  pname="${platform##*/}"                # android-37.0
  major="${pname%%.*}"                   # android-37
  ln -s "$platform" "$SDK_OVERLAY/platforms/$pname"
  if [ "$major" != "$pname" ]; then
    mkdir -p "$SDK_OVERLAY/platforms/$major"
    cp -rs "$platform/." "$SDK_OVERLAY/platforms/$major/"
    rm "$SDK_OVERLAY/platforms/$major/package.xml" "$SDK_OVERLAY/platforms/$major/source.properties"
    sed -e "s|path=\"platforms;$pname\"|path=\"platforms;$major\"|" \
        -e "s|<api-level>${pname#android-}<|<api-level>${major#android-}<|" \
        "$platform/package.xml" > "$SDK_OVERLAY/platforms/$major/package.xml"
    sed "s|^AndroidVersion.ApiLevel=${pname#android-}\$|AndroidVersion.ApiLevel=${major#android-}|" \
        "$platform/source.properties" > "$SDK_OVERLAY/platforms/$major/source.properties"
  fi
done

# Godot reads the SDK/JDK locations from editor settings (non-secret).
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CFG_DIR"
cat > "$CFG_DIR/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK_OVERLAY"
export/android/java_sdk_path = "$JAVA_HOME"
EOF

# Keystore config comes from the environment (kept out of export_presets.cfg).
# Set the full debug *and* release sets: Godot errors if only some debug vars are
# present (godotengine/godot#109551), so mirror the release key into both.
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$RELEASE_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER="$ANDROID_KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$ANDROID_KEYSTORE_PASSWORD"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RELEASE_KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ANDROID_KEY_ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$ANDROID_KEY_PASSWORD"

# Install the Android build template manually. Godot's
# --install-android-build-template deadlocks in headless mode, so unzip the
# template ourselves and write the version marker Godot checks (VERSION_FULL_CONFIG,
# which equals the export-template directory name, e.g. "4.7.stable").
# -L so find follows the export-templates symlink the dev shell creates into the
# Nix store.
ANDROID_SOURCE="$(find -L "$HOME" -path '*export_templates*/android_source.zip' 2>/dev/null | head -1)"
: "${ANDROID_SOURCE:?android_source.zip not found — is the dev shell linking export templates?}"
BUILD_VERSION="$(basename "$(dirname "$ANDROID_SOURCE")")"

rm -rf "$PROJECT/android/build"
mkdir -p "$PROJECT/android/build"
unzip -o -q "$ANDROID_SOURCE" -d "$PROJECT/android/build"
: > "$PROJECT/android/.gdignore"                          # keep the editor out of it
printf '%s\n' "$BUILD_VERSION" > "$PROJECT/android/.build_version"
printf '%s\n' "$BUILD_VERSION" > "$PROJECT/android/build/.build_version"

# Godot's template pins SDK 36 (compileSdk/targetSdk/buildTools), but the dev
# shell provides only platform/build-tools 37 and Gradle can't auto-install the
# missing platform into the read-only Nix store, so patch the extracted template
# up to 37. minSdk (24) and the NDK (29) are unchanged.
sed -i -E \
  -e "s|(compileSdk[[:space:]]*:)[[:space:]]*36,|\1 37,|" \
  -e "s|(targetSdk[[:space:]]*:)[[:space:]]*36,|\1 37,|" \
  -e "s|(buildTools[[:space:]]*:)[[:space:]]*'36\.[0-9.]+',|\1 '37.0.0',|" \
  "$PROJECT/android/build/config.gradle"

# AGP 8.6.1 predates API 37, so it warns it was only tested up to compileSdk 35.
# The overlay platform above resolves fine — silence the warning.
echo "android.suppressUnsupportedCompileSdk=37" >> "$PROJECT/android/build/gradle.properties"

# Enable the Gradle build and switch the preset's output to AAB (format 1).
sed -i \
  -e 's|gradle_build/use_gradle_build=false|gradle_build/use_gradle_build=true|' \
  -e 's|gradle_build/export_format=0|gradle_build/export_format=1|' \
  "$PROJECT/export_presets.cfg"

pushd "$PROJECT" >/dev/null
godot --headless --path . --import || true
godot --headless --path . --export-release "Android" "$OUT_AAB"
popd >/dev/null

echo "Built signed AAB: $OUT_AAB"
