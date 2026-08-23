# The development toolchains, from the shared definition.
#
# lib/dev-env.nix is the single list; this module is the home-manager consumer
# of it. The dev shell and any micro VM guest call the same function, so a
# language added there appears in all three.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  devEnv = import ../../lib/dev-env.nix {
    inherit pkgs lib;
    inherit (cfg) languages databases;
    agents = false; # home/dev/agents.nix owns those, gated separately
  };
in
{
  home.packages = devEnv.toolchains ++ devEnv.databasePackages;

  home.sessionVariables = lib.mkIf (builtins.elem "rust" cfg.languages) {
    RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
    CARGO_HOME = "${config.home.homeDirectory}/.cargo";
  };

  home.sessionPath = lib.optionals (builtins.elem "rust" cfg.languages) [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
