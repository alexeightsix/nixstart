# The login shell. $DOTFILES is exported because the alias files and
# copyline read it.
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
  programs.zsh = {
    enable = true;

    # ~/.zshrc rather than the XDG location, for anything that sources it by
    # path.
    dotDir = config.home.homeDirectory;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "docker-compose"
        "colorize"
        "fzf"
      ];
      theme = "dracula";
      # oh-my-zsh's own directory is read-only in the store, so the Dracula
      # theme is a custom-directory drop-in.
      custom = "${pkgs.dracula-zsh-theme}";
    };

    # Ghost text off — the grey inline suggestion that completes from history.
    autosuggestion.enable = false;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      share = true;
    };

    sessionVariables = {
      DOTFILES = "${cfg.checkout}/dotfiles";
      EDITOR = "nvim";
      DISABLE_AUTO_UPDATE = "true";
      DISABLE_UPDATE_PROMPT = "true";
      ZSH_TMUX_AUTOSTART = "false";
      SBX_WORKSPACE_ROOT = "${config.home.homeDirectory}/dev/spotlight-workspaces";
      FZF_DEFAULT_OPTS = lib.concatStringsSep " " [
        "--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9"
        "--color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9"
        "--color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6"
        "--color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
      ];
    };

    initContent = lib.mkMerge [
      # Machine-local secrets. Guarded: a missing file should cost you the
      # keys, not the shell.
      (lib.mkOrder 500 ''
        [ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"
      '')

      # `!copy` at the prompt -> last line of output on the clipboard. Sourced
      # last: it wraps whatever accept-line widget the plugins left in place.
      (lib.mkOrder 1500 ''
        [ -r "$DOTFILES/zsh/copyline.plugin.zsh" ] && source "$DOTFILES/zsh/copyline.plugin.zsh"
      '')

      # Yours, per machine. Never tracked, never overwritten — the one escape
      # hatch worth keeping.
      (lib.mkOrder 1550 ''
        [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
      '')
    ];
  };

  # The one directory the user's own scripts write to.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
}
