# Pi — the binary is managed, the configuration is not.
#
# Nix provides the environment and, since it is packaged, the agent itself.
# The configuration stays a working checkout: nothing here writes into
# ~/.pi/agent from the store, and no part of dotfiles/pi is copied into it.
#
# There are two reasons, and the second is the one that matters. The
# configuration is a live TypeScript project — extensions/, lib/, tests/ and a
# Docusaurus site under docs/ that is the acknowledged source of truth for the
# setup — edited daily and reloaded with /reload inside a running session.
# And Pi's runtime state (auth.json, sessions, models-store.json, npm packages
# it installs itself) has to stay untracked in the same directory the tracked
# files live in. A store path is read-only and cannot hold both halves.
#
# dotfiles/pi/link.sh already does this correctly — it symlinks the tracked
# files in, preserves anything already there, and prunes links whose source
# has been deleted. It is left to do its job; run it by hand, or turn on
# `linkConfig` below to have activation call it.
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
  options.nixstart.pi.linkConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Run dotfiles/pi/link.sh on activation, linking the tracked Pi
      configuration into ~/.pi/agent from the working checkout.

      Off by default: run it yourself once and Nix never touches the
      directory. The links it creates point at the checkout either way, so
      an edit is live in both cases.
    '';
  };

  config = lib.mkIf cfg.agents {
    # .zshrc put an unpacked upstream Node tarball on PATH for Pi —
    # ~/.local/share/pi-node/node-v22.23.2-linux-x64/bin — which is a
    # dynamically linked binary that will not run on NixOS at all.
    home.packages = [
      pkgs.nodejs
      pkgs.bun

      # pi itself. pi-launcher at ~/.local/bin/pi is only a dispatcher — it
      # searches PATH for the real executable and re-execs it — so without a
      # packaged pi anywhere it exited 127 with "real pi executable not found".
      # kickstart never installed pi either; its own docs say Pi is installed
      # separately, so a fresh machine had the launcher and nothing to launch.
      inputs.coding-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi-coding-agent
    ];

    # The launcher, by symlink to the checkout rather than into the store, so
    # editing pi-launcher does not need a rebuild.
    home.file.".local/bin/pi".source = config.lib.file.mkOutOfStoreSymlink "${piRepo}/pi-launcher";

    home.activation.linkPi = lib.mkIf config.nixstart.pi.linkConfig (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -x ${piRepo}/link.sh ]; then
          run ${pkgs.bash}/bin/bash ${piRepo}/link.sh
        fi
      ''
    );
  };
}
