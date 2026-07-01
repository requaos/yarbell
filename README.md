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
