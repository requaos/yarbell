# Yarbell

An Android game built with the [Godot](https://godotengine.org/) engine, with a
fully reproducible [Nix](https://nixos.org/) build pipeline. Every Android build
dependency (Godot, JDK 17, the Android SDK/NDK, build-tools, export templates) is
provided by the flake — there is nothing to install by hand.

## Requirements

- [Nix](https://nixos.org/) with flakes enabled (Determinate Nix works out of the box).
- That's it. The devshell and build supply everything else.

## Build the APK

```sh
nix build .#apk
```

This produces a signed **debug** APK at `result/yarbell.apk`. The first build
downloads the Android SDK/NDK and Godot export templates (a few hundred MB) and is
cached thereafter.

Install it on a device with USB debugging enabled:

```sh
"$ANDROID_HOME/build-tools/35.0.1/adb" install result/yarbell.apk   # or: adb install ...
```

## Release to GitHub Releases

Pushing a version tag builds a signed **APK** *and* **AAB** (Android App Bundle,
for the Play Store) and publishes both as GitHub Release assets. The workflow
lives in [`ci.nix`](ci.nix) (written in Nix via
[`actions.nix`](https://github.com/nialov/actions.nix)) and is rendered to
`.github/workflows/release.yaml`:

```sh
nix run .#render-workflows   # regenerate the YAML after editing ci.nix
```

`nix flake check` fails if the committed YAML drifts from `ci.nix`.

- **APK** — the Nix build produces an *unsigned* release APK
  (`nix build .#apk-release`), so your signing key never enters the Nix store; the
  workflow zipaligns and signs it with `apksigner` from secrets.
- **AAB** — an App Bundle requires Godot's Gradle build, which fetches
  dependencies at build time and so can't run in the pure Nix sandbox.
  [`scripts/build-aab.sh`](scripts/build-aab.sh) runs it inside `nix develop`
  (network available) and Godot signs it directly via release-keystore env vars.

Create these repository secrets first
(**Settings → Secrets and variables → Actions**):

| Secret | What it is |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Your release keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore (store) password |
| `ANDROID_KEY_ALIAS` | Key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | Key password for that alias |

Generate a keystore once and base64-encode it for the secret:

```sh
nix develop --command keytool -genkeypair -v \
  -keystore release.keystore -alias yarbell \
  -keyalg RSA -keysize 2048 -validity 10000
base64 < release.keystore | pbcopy   # paste into ANDROID_KEYSTORE_BASE64
```

Then cut a release:

```sh
git tag v0.1.0 && git push origin v0.1.0
```

(Running the workflow manually via **workflow_dispatch** builds and signs the APK
but skips publishing, since there is no tag.)

## Develop

Enter the dev shell for the Godot editor and all Android tooling on `PATH`:

```sh
nix develop
godot game/        # open the project in the editor
```

`ANDROID_HOME`, `ANDROID_SDK_ROOT`, and `JAVA_HOME` are exported automatically, and
the matching Godot export templates are linked into your Godot data directory on
first entry (non-destructively).

## Layout

```
flake.nix          Devshell + reproducible APK build (the core pipeline)
ci.nix             GitHub Actions release workflow, defined in Nix
.github/workflows/ Rendered workflow YAML (generated from ci.nix)
game/              The Godot project
  project.godot    App config, main scene, mobile renderer, portrait
  scenes/main.tscn Hello-world scene (centered label)
  scripts/main.gd  Startup script (logs "Yarbell booted")
  export_presets.cfg  Android export preset (prebuilt templates, no Gradle)
```

## How the build works

The APK is exported headlessly from prebuilt Godot export templates
(`gradle_build/use_gradle_build=false`), which keeps the build fully offline and
reproducible inside the Nix sandbox. The build stages the export templates and a
generated debug keystore into a temporary `HOME`, writes an `editor_settings-4.tres`
pointing Godot at the Nix-provided SDK/JDK, then runs `godot --headless --export-debug`.

> **Note:** enabling Gradle-based custom builds would require network access at build
> time and break sandboxed reproducibility. Keep `use_gradle_build=false` unless the
> pipeline is reworked to pre-populate the Gradle cache.
