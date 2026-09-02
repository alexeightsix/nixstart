# The development environment, defined once.
#
# Four things need it and none of them can import the others' module system:
# a NixOS host through home-manager, a `nix develop` shell, a guest with no
# home-manager through `environment.systemPackages`, and a plain home-manager
# account on a machine this repository does not own. So it is not a module — it is a
# function of pkgs and a few flags, returning package lists and environment.
# Every consumer is then three lines long.
#
#   home/dev/toolchains.nix   home.packages          = (devEnv {...}).packages
#   nixosModules.devEnv       environment.systemPackages = ...
#   devShells.<name>          mkShell { packages = ... }
#
# Tiers are separate rather than one flat list because a guest running one
# agent wants `base ++ agents ++ one language`, not everything the laptop has.
{
  pkgs,
  lib,
  languages ? [ ],
  agents ? false,
  databases ? false,
}:
let
  has = l: builtins.elem l languages;
in
rec {

  # Everything that makes a shell feel like this shell — the same set whether
  # you are on the desktop, ssh'd into a VM, or inside `nix develop`. An agent
  # that shells out to `rg` or `fd` finds them in all four.
  base = with pkgs; [
    zsh
    tmux
    neovim

    git
    gh
    delta
    lazygit

    fzf
    ripgrep
    fd
    eza
    bat
    zoxide
    atuin
    glow-rose-pine

    jq
    gettext
    curl
    wget
    unzip
    tree
    ncdu
    btop
    coreutils
    gnumake
    gcc
  ];

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

  agentPackages = lib.optionals agents (
    with pkgs;
    [
      claude-code
      codex
      opencode
      nodejs # Pi and the agents' own tooling
      bun
    ]
  );

  databasePackages = lib.optionals databases (
    with pkgs;
    [
      mariadb
      postgresql
    ]
  );

  packages = base ++ toolchains ++ agentPackages ++ databasePackages;

  # ANDROID_HOME and the three paths that have to be spelled out beside it.
  #
  # Named rather than folded straight into `env` because home/dev/toolchains.nix
  # wants precisely this set and none of the rest of it: on a home-manager
  # account EDITOR is already set, by programs.zsh.sessionVariables in
  # home/shell/zsh.nix, and putting the whole of `env` into
  # home.sessionVariables would leave it declared twice in two files.
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

  # Set the same way by every consumer, so a script that works in the dev
  # shell works over ssh in a VM.
  env = {
    EDITOR = "nvim";
    PAGER = "less -FRX";
  }
  // lib.optionalAttrs (has "rust") {
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
  }
  // androidEnv;
}
