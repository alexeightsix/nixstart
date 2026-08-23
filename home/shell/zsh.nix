# The login shell.
#
# .zshrc opened by deriving $DOTFILES from `${${(%):-%x}:A:h}` — the file being
# sourced, resolved back through the symlink link.sh had made — so the clone
# could be named anything and sit anywhere. Nix knows the path at build time,
# so the trick stops being load-bearing; $DOTFILES is still exported, because
# the alias files and copyline read it.
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

    # ~/.zshrc, where it has always been. The XDG location is the future
    # default, but every script and instance that sources ~/.zshrc by path —
    # and .zshrc.local, and the Incus provisioning — would have to move with it.
    dotDir = config.home.homeDirectory;

    # The three curl-piped installers stage-05 ran are packages now, and
    # oh-my-zsh no longer has to be talked out of overwriting the .zshrc
    # link.sh had just put there with KEEP_ZSHRC=yes CHSH=no RUNZSH=no.
    oh-my-zsh = {
      enable = true;
      plugins = [
        "docker-compose"
        "colorize"
        "fzf"
        "tmux"
      ];
      theme = "dracula";
      # oh-my-zsh's own directory is read-only in the store, so the Dracula
      # theme is a custom-directory drop-in rather than a git clone copied
      # into ~/.oh-my-zsh/themes the way stage-05 did it.
      custom = "${pkgs.dracula-zsh-theme}";
    };

    autosuggestion.enable = true;
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
      # Machine-local secrets. Still guarded: a machine with no secrets file
      # should cost you the keys, not the shell.
      (lib.mkOrder 500 ''
        [ -f "$HOME/.zsh_secrets" ] && source "$HOME/.zsh_secrets"
      '')

      # How this shell was reached, for the tmux status bar. lazyincus sets
      # DEV_VIA on the way in and each hop appends itself, so by the time a
      # prompt appears it reads something like `tui>ssh`. tmux is added here
      # because this is the first thing that knows it is inside one; the
      # %>tmux strip keeps re-sourcing idempotent, and -p is pane-scoped so a
      # pane opened over ssh and one opened through `incus exec` each keep
      # their own trail.
      (lib.mkOrder 1000 ''
        if [ -n "$DEV_VIA" ] && [ -n "$TMUX" ]; then
          export DEV_VIA="''${DEV_VIA%>tmux}>tmux"
          command tmux set -p @dev_via "$DEV_VIA" 2>/dev/null
        fi
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

  # Every `export PATH=` line in .zshrc was a language runtime's installer
  # announcing where it had put itself — .cargo, .bun, .opencode, .npm-global,
  # .local/share/pnpm, .grok, and a Node tarball pinned by full path for Pi
  # (~/.local/share/pi-node/node-v22.23.2-linux-x64/bin). Those installers are
  # gone. What is left is the one directory the user's own scripts write to.
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
}
