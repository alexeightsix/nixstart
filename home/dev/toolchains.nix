# Language toolchains.
#
# Between stage-01 (dnf: golang, nodejs, npm, python3, luarocks), stage-06
# (rustup via curl), stage-10 (PHP from the Remi repo, plus composer from
# getcomposer.org) and a handful of `PATH=` lines in .zshrc for bun, pnpm and
# a global npm prefix, "which languages does this machine have" was a question
# you answered by reading five files. It is a list now.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  has = l: builtins.elem l cfg.languages;
in
{
  home.packages =
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
    ]
    ++ lib.optionals (has "php") [
      php84
      php84Packages.composer
    ]
    ++ lib.optionals (has "python") [
      python3
      uv
    ]
    ++ lib.optionals (has "lua") [
      lua
      luarocks
    ]
    # rustup rather than a pinned toolchain: lua/config/lsp.lua's comment says
    # rust-analyzer comes from rustup deliberately, "which keeps it matched to
    # the compiler the project is actually built with". Overriding that here
    # would be a change of behaviour, not a port.
    ++ lib.optionals (has "rust") [ rustup ];

  home.sessionVariables = lib.mkIf (has "rust") {
    RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
    CARGO_HOME = "${config.home.homeDirectory}/.cargo";
  };

  home.sessionPath = lib.optionals (has "rust") [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
