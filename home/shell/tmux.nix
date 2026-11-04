# tmux.conf is 151 lines of key tables and status-bar format strings, several
# of which read the @dev_via pane variable zsh sets. It translates to
# `programs.tmux.extraConfig` unchanged; there is nothing for the option tree
# to add.
#
# tpm is a runtime git clone nothing here installs, so its
# `run '~/.tmux/plugins/tpm/tpm'` line is replaced in place with the Nix
# plugins, same order. Not `programs.tmux.plugins`: that loads them at a
# fixed point, and the lines after tpm in tmux.conf are written to override
# the plugins. The `set -g @plugin` lines are left alone (inert without tpm).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  # Same order as the @plugin declarations at the top of tmux.conf. tpm is not
  # in the list — it only ever existed to fetch the other five.
  plugins = with pkgs.tmuxPlugins; [
    sensible
    vim-tmux-navigator
    yank
    rose-pine
    tmux-fzf
  ];

  tpmLine = "run '~/.tmux/plugins/tpm/tpm'";
  loadPlugins = lib.concatMapStringsSep "\n" (p: "run-shell ${p.rtp}") plugins;

  source = builtins.readFile "${cfg.dotfiles}/tmux.conf";
  tmuxConf = builtins.replaceStrings [ tpmLine ] [ loadPlugins ] source;
in
{
  # replaceStrings fails open — if the line is ever reworded the plugins
  # silently go missing. Better to break the build.
  assertions = [
    {
      assertion = lib.hasInfix tpmLine source;
      message = ''
        home/shell/tmux.nix expects dotfiles/tmux.conf to load its plugins with
        ${tpmLine}
        and that line is no longer in the file. Update tpmLine to match, or the
        plugins will silently not load.
      '';
    }
  ];

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    escapeTime = 0;
    historyLimit = 100000;
    keyMode = "vi";
    extraConfig = tmuxConf;
  };

  # tmux.conf binds prefix+n and prefix+r to these two helpers, by the paths
  # below. They are read from the store with the config that references them,
  # so a binding and the script it runs can never be from different commits.
  home.file = {
    ".config/tmux/tmux-rename.sh".source = "${cfg.dotfiles}/tmux/tmux-rename.sh";
    ".config/tmux/tmux-rename.inputrc".source = "${cfg.dotfiles}/tmux/tmux-rename.inputrc";
    ".config/tmux/tmux-session.sh".source = "${cfg.dotfiles}/tmux/tmux-session.sh";
    ".config/tmux/tmux-session.inputrc".source = "${cfg.dotfiles}/tmux/tmux-session.inputrc";
  };
}
