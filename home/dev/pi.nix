# Pi.
#
# Two things make this different from the rest of the repository, and both are
# reasons to keep Nix's hands off the contents.
#
# First, the extension set is a live TypeScript project — extensions/, lib/,
# tests/ and a Docusaurus site under docs/ that is the acknowledged source of
# truth for the setup. It is edited daily and its tests are run in place.
#
# Second, pi/link.sh already solves the exact problem home-manager would: it
# symlinks each tracked file into ~/.pi/agent, preserves anything that was
# there, and prunes links whose source has been removed — because runtime
# state (auth.json, sessions, models-store.json, installed npm packages) has
# to stay untracked in that same directory. A store path cannot hold both.
#
# So this module puts Pi's dependencies in place and runs that script. The
# links point at the working checkout, which is what makes `/reload` in a
# running session pick up an edit.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
  piRepo = "${cfg.checkout}/dotfiles/pi";
in
{
  config = lib.mkIf cfg.agents {
    # .zshrc put a specific Node tarball on PATH for Pi:
    # ~/.local/share/pi-node/node-v22.23.2-linux-x64/bin. That directory is an
    # unpacked upstream release, which will not run here.
    home.packages = with pkgs; [
      nodejs
      bun
    ];

    home.file.".local/bin/pi".source = config.lib.file.mkOutOfStoreSymlink "${piRepo}/pi-launcher";

    home.activation.linkPi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -x ${piRepo}/link.sh ]; then
        run ${pkgs.bash}/bin/bash ${piRepo}/link.sh
      fi
    '';
  };
}
