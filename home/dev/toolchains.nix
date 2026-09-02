# The development toolchains, from the shared definition.
#
# lib/dev-env.nix is the single list; this module is the home-manager consumer
# of it. The dev shell and any guest call the same function, so a language
# added there appears in all three.
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

  home.sessionVariables = lib.mkMerge [
    (lib.mkIf (builtins.elem "rust" cfg.languages) {
      RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
      CARGO_HOME = "${config.home.homeDirectory}/.cargo";
    })

    # ANDROID_HOME, JAVA_HOME and the aapt2 override, taken from the shared
    # definition rather than restated. Unlike the rust pair above these are
    # store paths that have to match the SDK actually installed, so a copy
    # here would be a copy that goes stale on the next Expo bump.
    #
    # This is what `expo start` reads. It is a login-session variable, so a
    # terminal that was already open when the rebuild ran still has the old
    # environment — or none — and has to be restarted before the Android SDK
    # warning goes away.
    devEnv.androidEnv
  ];

  home.sessionPath = lib.optionals (builtins.elem "rust" cfg.languages) [
    "${config.home.homeDirectory}/.cargo/bin"
  ];
}
