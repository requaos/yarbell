{
  description = "Yarbell — an Android game built with the Godot engine, packaged with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    actions-nix.url = "github:nialov/actions.nix";
  };

  outputs = { self, nixpkgs, flake-utils, actions-nix }:
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

        # Used for apksigner/zipalign when signing the release APK.
        buildToolsVersion = "36.1.0";

        # All Android build dependencies, pinned to what Godot 4.7's Gradle build
        # template requires for the AAB export (platform/build-tools/NDK 36/29).
        # Gradle cannot auto-install them into the read-only Nix store, so they must
        # be provided here. The internal (non-Gradle) APK export uses these too.
        androidComposition = pkgs.androidenv.composeAndroidPackages {
          cmdLineToolsVersion = "19.0";
          platformToolsVersion = "36.0.0";
          buildToolsVersions = [ buildToolsVersion ];
          platformVersions = [ "36" ];
          includeNDK = true;
          ndkVersions = [ "29.0.14206865" ];
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

        # Build a Godot Android APK. The debug variant signs with the committed,
        # stable debug keystore (so `adb install -r` works across rebuilds). The
        # release variant emits an *unsigned* APK: release signing happens later
        # from CI secrets, so the keystore never enters the Nix store.
        mkApk = { release ? false }:
          let
            exportMode = if release then "--export-release" else "--export-debug";
            outName = if release then "yarbell-unsigned.apk" else "yarbell.apk";
            label = if release then "unsigned release" else "debug";
          in
          pkgs.stdenv.mkDerivation {
            pname = "yarbell-apk${pkgs.lib.optionalString release "-release"}";
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

              ${pkgs.lib.optionalString release ''
                # Release APKs are signed later (in CI, from secrets), never in
                # the Nix store. Disable Godot's own signing so it emits an
                # unsigned APK for the workflow to zipalign + apksigner.
                sed -i 's|package/signed=true|package/signed=false|' \
                  "$TMPDIR/project/export_presets.cfg"
              ''}

              # Stage the Android export templates where Godot looks for them.
              # The templates package contains exactly one version directory
              # (e.g. "4.6.3.stable"); its name must match the engine version.
              tmplSrc="${templates}/share/godot/export_templates"
              ver="$(ls "$tmplSrc")"
              mkdir -p "$HOME/${godotDataSubdir}/export_templates"
              cp -r "$tmplSrc/$ver" "$HOME/${godotDataSubdir}/export_templates/$ver"
              chmod -R u+w "$HOME/${godotDataSubdir}/export_templates/$ver"

              # Use the committed, stable debug keystore for debug signing.
              cp "${./keystore/debug.keystore}" "$HOME/debug.keystore"
              chmod u+w "$HOME/debug.keystore"

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

              # Import assets, then export the ${label} APK headlessly.
              mkdir -p "$out"
              pushd "$TMPDIR/project" > /dev/null
              godot --headless --path . --import || true
              godot --headless --path . ${exportMode} "Android" "$out/${outName}"
              popd > /dev/null

              runHook postBuild
            '';

            meta = with pkgs.lib; {
              description = "Yarbell Android ${label} APK";
              platforms = platforms.all;
            };
          };

        apk = mkApk { };
        apkRelease = mkApk { release = true; };

        # GitHub Actions workflows are written in Nix (see ./ci.nix) and rendered
        # to .github/workflows/*.yaml via `nix run .#render-workflows`.
        actionsEval = actions-nix.lib.evalModule pkgs ./ci.nix;
      in
      {
        packages = {
          default = apk;
          apk = apk;
          apk-release = apkRelease;
          render-workflows = actionsEval.config.build.renderWorkflows;
        };

        # `nix flake check` fails if the committed workflow YAML drifts from ci.nix.
        checks.actions = actionsEval.config.build.check self;

        devShells.default = pkgs.mkShell {
          # unzip is used by scripts/build-aab.sh to install the Android build
          # template (Godot's --install-android-build-template hangs headless).
          packages = [ godot jdk androidComposition.androidsdk pkgs.unzip ];

          ANDROID_HOME = sdkRoot;
          ANDROID_SDK_ROOT = sdkRoot;
          JAVA_HOME = jdk.home;
          # Absolute path to the pinned build-tools (apksigner/zipalign) so CI and
          # local shells can sign APKs without guessing the version directory.
          ANDROID_BUILD_TOOLS = "${sdkRoot}/build-tools/${buildToolsVersion}";

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
            echo "  Build APK :  nix build .#apk           (-> result/yarbell.apk)"
            echo "  Release   :  nix build .#apk-release    (unsigned; CI signs it)"
            echo ""
          '';
        };
      });
}
