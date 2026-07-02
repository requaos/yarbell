{
  # Written in Nix and rendered to YAML via `nix run .#render-workflows`.
  # `nix flake check` verifies the committed YAML matches this file.
  defaultValues.jobs.runs-on = "ubuntu-latest";

  workflows.".github/workflows/release.yaml" = {
    name = "release";

    # Build and publish on version tags (e.g. `v0.1.0`); also runnable manually
    # for a dry run (the publish step is skipped when there is no tag).
    on = {
      push.tags = [ "v*" ];
      workflow_dispatch = { };
    };

    # Needed for softprops/action-gh-release to create the release + upload asset.
    permissions.contents = "write";

    jobs.release.steps = [
      { uses = "actions/checkout@v4"; }
      {
        name = "Install Nix";
        uses = "cachix/install-nix-action@v31";
        "with".extra_nix_config = "experimental-features = nix-command flakes";
      }
      {
        name = "Decode the release keystore";
        env.ANDROID_KEYSTORE_BASE64 = "\${{ secrets.ANDROID_KEYSTORE_BASE64 }}";
        run = ''echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/release.keystore"'';
      }
      {
        name = "Build unsigned release APK";
        run = "nix build .#apk-release -L";
      }
      {
        name = "Sign the release APK";
        env = {
          ANDROID_KEYSTORE_PASSWORD = "\${{ secrets.ANDROID_KEYSTORE_PASSWORD }}";
          ANDROID_KEY_ALIAS = "\${{ secrets.ANDROID_KEY_ALIAS }}";
          ANDROID_KEY_PASSWORD = "\${{ secrets.ANDROID_KEY_PASSWORD }}";
        };
        run = ''
          set -euo pipefail
          # zipalign + apksigner come from the pinned build-tools in the dev shell,
          # so signing is reproducible and needs no runner-provided Android SDK.
          nix develop --command bash -c '
            set -euo pipefail
            "$ANDROID_BUILD_TOOLS/zipalign" -f -p 4 \
              result/yarbell-unsigned.apk yarbell-aligned.apk
            "$ANDROID_BUILD_TOOLS/apksigner" sign \
              --ks "$RUNNER_TEMP/release.keystore" \
              --ks-pass env:ANDROID_KEYSTORE_PASSWORD \
              --ks-key-alias "$ANDROID_KEY_ALIAS" \
              --key-pass env:ANDROID_KEY_PASSWORD \
              --out yarbell.apk \
              yarbell-aligned.apk
            "$ANDROID_BUILD_TOOLS/apksigner" verify --verbose yarbell.apk
          '
        '';
      }
      {
        name = "Build the signed release AAB";
        # An AAB needs Godot's Gradle build (fetches deps), so it runs in the dev
        # shell rather than the sandboxed nix build. Godot signs it via the
        # release-keystore env vars set by scripts/build-aab.sh.
        env = {
          RELEASE_KEYSTORE = "\${{ runner.temp }}/release.keystore";
          ANDROID_KEY_ALIAS = "\${{ secrets.ANDROID_KEY_ALIAS }}";
          ANDROID_KEYSTORE_PASSWORD = "\${{ secrets.ANDROID_KEYSTORE_PASSWORD }}";
          ANDROID_KEY_PASSWORD = "\${{ secrets.ANDROID_KEY_PASSWORD }}";
          OUT_AAB = "\${{ github.workspace }}/yarbell.aab";
        };
        run = "nix develop --command bash scripts/build-aab.sh";
      }
      {
        name = "Publish APK + AAB to GitHub Releases";
        "if" = "startsWith(github.ref, 'refs/tags/')";
        uses = "softprops/action-gh-release@v2";
        "with" = {
          files = "yarbell.apk\nyarbell.aab";
          fail_on_unmatched_files = true;
        };
      }
    ];
  };
}
