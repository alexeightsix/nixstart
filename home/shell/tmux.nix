# tmux.conf is 151 lines of key tables and status-bar format strings, several
# of which read the @dev_via pane variable zsh sets. It translates to
# `programs.tmux.extraConfig` unchanged; there is nothing for the option tree
# to add.
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
  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "vi";
    extraConfig = builtins.readFile "${cfg.dotfiles}/tmux.conf";
  };

  # tmux.conf binds prefix+r and prefix+s to these two helpers, by the paths
  # below. They are read from the store with the config that references them,
  # so a binding and the script it runs can never be from different commits.
  home.file = {
    ".config/tmux/tmux-rename.sh".source = "${cfg.dotfiles}/tmux/tmux-rename.sh";
    ".config/tmux/tmux-rename.inputrc".source = "${cfg.dotfiles}/tmux/tmux-rename.inputrc";
    ".config/tmux/tmux-session.sh".source = "${cfg.dotfiles}/tmux/tmux-session.sh";
    ".config/tmux/tmux-session.inputrc".source = "${cfg.dotfiles}/tmux/tmux-session.inputrc";
  };
}
