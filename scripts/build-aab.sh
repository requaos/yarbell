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

# Godot reads the SDK/JDK locations from editor settings (non-secret).
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"
mkdir -p "$CFG_DIR"
cat > "$CFG_DIR/editor_settings-4.tres" <<EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$ANDROID_HOME"
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
