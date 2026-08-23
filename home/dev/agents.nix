# Coding agents.
#
# Every one of these arrived through its own curl-to-bash installer or npm
# global (stage-15 for claude, .zshrc PATH lines for opencode and grok), and
# update-packages.sh then had to call four different `update` subcommands.
# Three of the four are packaged; the fourth is below.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
in
{
  config = lib.mkIf cfg.agents {
    home.packages = with pkgs; [
      claude-code
      codex
      opencode
    ];
  };
}
