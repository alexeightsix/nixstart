# Coding agents.
#
# Every one arrived through its own curl-to-bash installer or npm global —
# stage-15 for claude, and PATH lines in .zshrc for opencode
# (~/.opencode/bin), a global npm prefix (~/.npm-global/bin) and grok
# (~/.grok/bin, with its own compinit block at the end of the file).
# update-packages.sh then called four different `update` subcommands to keep
# them current.
#
# Pi is the fifth and is handled separately, in pi.nix — it is a working
# checkout, not a package.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  config = lib.mkIf cfg.agents {
    # grok-cli is in nixpkgs now, so `grok` comes from the store like the other
    # three. It was previously carried as a PATH entry pointing at ~/.grok/bin,
    # where its curl installer had put a Node application on Fedora — but
    # nothing on a NixOS install ever creates that directory, so the export and
    # the fpath line beside it silently added nothing and `grok` was the one
    # agent that simply was not installed. The package ships bin/grok and no
    # zsh completions, so the fpath line has no replacement and is dropped
    # rather than left pointing at a path that will never exist.
    home.packages = with pkgs; [
      claude-code
      codex
      opencode
      grok-cli
    ];
  };
}
