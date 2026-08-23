# The development environment, defined once.
#
# Four things need it and none of them can import the others' module system:
# a NixOS host through home-manager, a `nix develop` shell, a micro VM guest
# through `environment.systemPackages`, and a plain home-manager account on a
# machine this repository does not own. So it is not a module — it is a
# function of pkgs and a few flags, returning package lists and environment.
# Every consumer is then three lines long.
#
#   home/dev/toolchains.nix   home.packages          = (devEnv {...}).packages
#   nixosModules.devEnv       environment.systemPackages = ...
#   devShells.<name>          mkShell { packages = ... }
#
# Tiers are separate rather than one flat list because a micro VM running one
# agent wants `base ++ agents ++ one language`, not everything the desktop has.
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

  # Set the same way by every consumer, so a script that works in the dev
  # shell works over ssh in a VM.
  env = {
    EDITOR = "nvim";
    PAGER = "less -FRX";
  }
  // lib.optionalAttrs (has "rust") {
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
  };
}
