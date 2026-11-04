# Pi — the binary is managed, the configuration is not.
#
# Nix provides the environment and, since it is packaged, the agent itself.
# The configuration stays a working checkout: nothing here writes into
# ~/.pi/agent from the store, and no part of dotfiles/pi is copied into it.
#
# The configuration is a live TypeScript project edited daily and reloaded
# with /reload, and Pi's untracked runtime state (auth.json, sessions, ...)
# lives in the same directory, which a read-only store path cannot hold.
#
# Activation runs dotfiles/pi/link.sh, which symlinks the tracked files in,
# preserves anything already there, and prunes links whose source is gone.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  piRepo = "${cfg.checkout}/dotfiles/pi";
in
{
  config = lib.mkIf cfg.agents {
    home.packages = [
      pkgs.nodejs
      pkgs.bun

      # pi itself.
      inputs.coding-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    ];

    # dotfiles/pi/pi-launcher is deliberately NOT linked to ~/.local/bin/pi:
    # it re-execs pi under a bundled node, and the packaged pi is an ELF
    # wrapper, so node would try to parse it as JavaScript.

    home.activation.linkPi = (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -x ${piRepo}/link.sh ]; then
          run ${pkgs.bash}/bin/bash ${piRepo}/link.sh
        fi
      ''
    );
  };
}
