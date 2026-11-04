# The development toolchains: one list per entry in nixstart.home.languages.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  has = l: builtins.elem l cfg.languages;

  toolchains =
    with pkgs;
    lib.optionals (has "go") [
      go
      gopls
      golangci-lint
    ]
    ++ lib.optionals (has "node") [
      nodejs
      pnpm
      bun
      typescript
      typescript-language-server
      vscode-langservers-extracted
      prettierd
    ]
    ++ lib.optionals (has "php") [
      php84
      php84Packages.composer
      intelephense
    ]
    ++ lib.optionals (has "python") [
      python3
      uv
    ]
    ++ lib.optionals (has "lua") [
      lua
      luarocks
      lua-language-server
      stylua
    ]
    ++ lib.optionals (has "rust") [ rustup ]
    ++ lib.optionals (has "android") [
      # The SDK puts adb, emulator, sdkmanager and avdmanager on PATH itself,
      # so there is no separate android-tools here — two adbs on one machine
      # is how you end up with a client and a server of different versions
      # killing each other's daemon.
      android-sdk.sdk

      # 17, not the newest. Android Gradle Plugin 8, which is what React
      # Native 0.81 generates a build for, rejects a JDK newer than 17 with
      # "Unsupported class file major version" rather than falling back.
      jdk17

      # Only ever for `gradle --version` and for repairing a wrapper: a
      # generated Expo project builds through its own ./gradlew, which
      # downloads the distribution its gradle-wrapper.properties pins and
      # ignores this one entirely. nixpkgs happens to carry 8.14, the same
      # series that wrapper asks for, so the two agree — but the wrapper is
      # what actually runs, and it is the file to look at when a build takes
      # a Gradle version by surprise.
      gradle
    ]
    ++ lib.optionals (has "gtk") [
      gtk4
      libadwaita
      blueprint-compiler
      pkg-config
      gobject-introspection
    ];

  databasePackages = lib.optionals cfg.databases (
    with pkgs;
    [
      mariadb
      postgresql
    ]
  );

  # ANDROID_HOME and the three paths that have to be spelled out beside it.
  androidEnv = lib.optionalAttrs (has "android") {
    # Expo's assertSdkRoot() reads ANDROID_HOME, then the deprecated
    # ANDROID_SDK_ROOT, then ~/Android/sdk, and the absence of all three is
    # what produced "Failed to resolve the Android SDK path" and then, on the
    # fallback to a global adb that was equally absent, `spawn adb ENOENT`.
    #
    # Only the current variable is set. ANDROID_SDK_ROOT still works and would
    # be found second, but AGP warns whenever it sees it, and one of the two
    # being stale is a worse failure than either being unset.
    ANDROID_HOME = pkgs.android-sdk.root;

    # Not what makes a React Native build work: Gradle takes the ndkVersion
    # out of build.gradle and looks under $ANDROID_HOME/ndk/<version> itself.
    # This is for everything that has no build.gradle to read — cmake run by
    # hand, native tooling invoked outside Gradle — which looks for the
    # variable and otherwise finds nothing.
    ANDROID_NDK_ROOT = pkgs.android-sdk.ndkRoot;

    JAVA_HOME = pkgs.jdk17.home;

    # The one NixOS-specific line here, and a build fails without it.
    #
    # AGP does not use the aapt2 in the SDK. It resolves its own from Maven as
    # a jar, unpacks a prebuilt Linux ELF out of it and executes that — linked
    # against an interpreter at /lib64/ld-linux-x86-64.so.2, which is the one
    # path a NixOS machine does not have. Every resource-linking task then
    # fails with ENOENT naming a binary that is visibly right there, which is
    # a confusing enough error to be worth the paragraph.
    #
    # This is AGP's own escape hatch for the case, pointed at the SDK's aapt2,
    # which androidenv has already patched for this system.
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${pkgs.android-sdk.aapt2}";
  };
in
{
  home.packages = toolchains ++ databasePackages;

  home.sessionVariables = lib.mkMerge [
    (lib.mkIf (has "rust") {
      RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
      CARGO_HOME = "${config.home.homeDirectory}/.cargo";
    })

    # This is what `expo start` reads. It is a login-session variable, so a
    # terminal that was already open when the rebuild ran still has the old
    # environment — or none — and has to be restarted before the Android SDK
    # warning goes away.
    androidEnv
  ];

  home.sessionPath = lib.optionals (has "rust") [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
