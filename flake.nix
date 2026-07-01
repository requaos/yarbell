{
  description = "Yarbell — an Android game built with the Godot engine, packaged with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        godot = pkgs.godot_4;
        templates = pkgs.godot_4-export-templates-bin;
        jdk = pkgs.jdk17;

        # All Android build dependencies, pinned to what Godot 4.6 expects.
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "19.0";
          platformToolsVersion = "35.0.2";
          buildToolsVersions = [ "35.0.1" ];
          platformVersions = [ "35" ];
          includeNDK = true;
          ndkVersions = [ "28.1.13356709" ];
          cmakeVersions = [ "3.22.1" ];
          # The emulator is broken/unavailable on aarch64-darwin and is not
          # needed for headless APK export.
          includeSystemImages = false;
          includeEmulator = false;
        };

        sdkRoot = "${androidComposition.androidsdk}/libexec/android-sdk";

        # Godot's data/config directory layout differs per host OS.
        godotDataSubdir =
          if pkgs.stdenv.isDarwin
          then "Library/Application Support/Godot"
          else ".local/share/godot";
        godotConfigSubdir =
          if pkgs.stdenv.isDarwin
          then "Library/Application Support/Godot"
          else ".config/godot";

        apk = pkgs.stdenv.mkDerivation {
          pname = "yarbell-apk";
          version = "0.1.0";
          src = ./game;

          # keytool comes from the JDK; Godot invokes the SDK's build-tools
          # (apksigner/zipalign/aapt2) via absolute paths from android_sdk_path.
          nativeBuildInputs = [ godot jdk ];

          dontUnpack = true;
          dontConfigure = true;
          dontInstall = true;

          buildPhase = ''
            runHook preBuild

            export HOME="$TMPDIR/home"
            export ANDROID_HOME="${sdkRoot}"
            export ANDROID_SDK_ROOT="${sdkRoot}"
            export JAVA_HOME="${jdk.home}"
            mkdir -p "$HOME"

            # Writable copy of the project (Godot writes an import cache into it).
            cp -r "${./game}" "$TMPDIR/project"
            chmod -R u+w "$TMPDIR/project"

            # Stage the Android export templates where Godot looks for them.
            # The templates package contains exactly one version directory
            # (e.g. "4.6.3.stable"); its name must match the engine version.
            tmplSrc="${templates}/share/godot/export_templates"
            ver="$(ls "$tmplSrc")"
            mkdir -p "$HOME/${godotDataSubdir}/export_templates"
            cp -r "$tmplSrc/$ver" "$HOME/${godotDataSubdir}/export_templates/$ver"
            chmod -R u+w "$HOME/${godotDataSubdir}/export_templates/$ver"

            # Generate the standard Android debug keystore.
            keytool -keyalg RSA -genkeypair -alias androiddebugkey \
              -keypass android -keystore "$HOME/debug.keystore" -storepass android \
              -dname "CN=Android Debug,O=Android,C=US" -validity 9999 \
              -deststoretype pkcs12

            # Point Godot at the SDK, JDK, and debug keystore via editor settings
            # (the keystore has no environment-variable equivalent).
            mkdir -p "$HOME/${godotConfigSubdir}"
            cat > "$HOME/${godotConfigSubdir}/editor_settings-4.tres" <<EOF
            [gd_resource type="EditorSettings" format=3]

            [resource]
            export/android/android_sdk_path = "${sdkRoot}"
            export/android/java_sdk_path = "${jdk.home}"
            export/android/debug_keystore = "$HOME/debug.keystore"
            export/android/debug_keystore_user = "androiddebugkey"
            export/android/debug_keystore_pass = "android"
            EOF

            # Import assets, then export the debug APK headlessly.
            mkdir -p "$out"
            pushd "$TMPDIR/project" > /dev/null
            godot --headless --path . --import || true
            godot --headless --path . --export-debug "Android" "$out/yarbell.apk"
            popd > /dev/null

            runHook postBuild
          '';

          meta = with pkgs.lib; {
            description = "Yarbell hello-world Android debug APK";
            platforms = platforms.all;
          };
        };
      in
      {
        packages = {
          default = apk;
          apk = apk;
        };

        devShells.default = pkgs.mkShell {
          packages = [ godot jdk androidComposition.androidsdk ];

          ANDROID_HOME = sdkRoot;
          ANDROID_SDK_ROOT = sdkRoot;
          JAVA_HOME = jdk.home;

          shellHook = ''
            # Non-destructively make the export templates available to the
            # editor: only create the version-specific symlink if absent, and
            # never touch the developer's editor settings.
            tmplSrc="${templates}/share/godot/export_templates"
            ver="$(ls "$tmplSrc")"
            dest="$HOME/${godotDataSubdir}/export_templates/$ver"
            if [ ! -e "$dest" ]; then
              mkdir -p "$(dirname "$dest")"
              ln -s "$tmplSrc/$ver" "$dest"
              echo "yarbell: linked Godot $ver export templates -> $dest"
            fi

            echo ""
            echo "  Yarbell dev shell"
            echo "  godot        : $(command -v godot) ($(godot --version 2>/dev/null))"
            echo "  ANDROID_HOME : $ANDROID_HOME"
            echo "  JAVA_HOME    : $JAVA_HOME"
            echo ""
            echo "  Edit game :  godot game/"
            echo "  Build APK :  nix build .#apk   (-> result/yarbell.apk)"
            echo ""
          '';
        };
      });
}
