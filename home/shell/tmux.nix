# tmux.conf is 151 lines of key tables and status-bar format strings, several
# of which read the @dev_via pane variable zsh sets. It translates to
# `programs.tmux.extraConfig` unchanged; there is nothing for the option tree
# to add.
#
# The one thing that did not survive the move from kickstart is tpm. tmux.conf
# declares six plugins at the top and then loads them, on line 89, with
#
#   run '~/.tmux/plugins/tpm/tpm'
#
# which is a runtime git clone into $HOME that nothing in this repository
# installs. So every `@plugin` line was silently inert on a fresh machine — no
# rose-pine theme, no vim-tmux-navigator bindings, no yank, no fzf — and tmux
# came up as plain tmux wearing the local key bindings. Nothing errored; the
# plugins simply were not there.
#
# home-manager's `programs.tmux.plugins` is the obvious replacement and is the
# wrong shape for this file: it appends the plugin loads at a fixed point,
# whereas this config cares where they land. Everything from line 90 down is
# written to run *after* tpm and says so in its own comments ("after tpm so it
# appends", "after tpm so it overrides rose-pine"). Loading the plugins last
# would let rose-pine win those overrides back.
#
# So the tpm line is replaced in place, with the same plugins in the same
# order, and the ordering the file was written around is preserved exactly.
# The `set -g @plugin` lines are left alone: inert without tpm, and keeping
# them means this file stays byte-identical to the kickstart copy.
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
  # replaceStrings fails open — if the line is ever reworded the substitution
  # quietly does nothing and the plugins go missing again, which is the exact
  # failure being fixed here. Better to break the build.
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
