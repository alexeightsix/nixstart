# A `nix develop` shell that behaves like the desktop.
#
# The hard part is not the packages — it is that a dev shell drops you into
# bash with none of the shell configuration, so the aliases, the history and
# the prompt are all missing exactly when an agent is about to run. There is no
# home-manager here to generate ~/.zshrc.
#
# So the rc files are generated directly and the shell is pointed at them with
# ZDOTDIR, which zsh reads instead of $HOME. Nothing is written to the real
# home directory, so this is safe to run on a machine whose shell setup you do
# not want touched — including one that is not NixOS at all.
{
  pkgs,
  lib,
  devEnv,
  dotfiles ? null,
  name ? "dev",
}:
let
  # The alias directory is sourced at runtime when it is available, exactly as
  # it is on the desktop, so adding an alias does not mean rebuilding a shell.
  aliasDir = if dotfiles == null then null else "${dotfiles}/zsh/alias";

  zdotdir = pkgs.runCommand "${name}-zdotdir" { } ''
    mkdir -p "$out"
    cat > "$out/.zshrc" <<'EOF'
    # Generated for `nix develop`. Not the desktop's .zshrc — that one is
    # home-manager's — but the same aliases, tools and keys.
    export DEV_SHELL=${name}

    autoload -Uz compinit && compinit -C
    autoload -Uz colors && colors

    setopt AUTO_CD INTERACTIVE_COMMENTS
    setopt HIST_IGNORE_DUPS SHARE_HISTORY
    HISTSIZE=100000 SAVEHIST=100000
    HISTFILE="''${XDG_STATE_HOME:-$HOME/.local/state}/zsh-${name}-history"
    mkdir -p "$(dirname "$HISTFILE")"

    ${lib.optionalString (aliasDir != null) ''
      for alias_file in ${aliasDir}/*(N); do
        source "$alias_file"
      done
      unset alias_file
    ''}

    command -v zoxide >/dev/null && eval "$(zoxide init zsh)"
    command -v atuin  >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

    # A prompt that says where you are, because the whole point of this shell
    # is that an agent is running somewhere that is not your desktop.
    PROMPT='%F{magenta}(${name})%f %F{blue}%~%f %# '

    [ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
    EOF
  '';

  tmuxConf = if dotfiles == null then pkgs.writeText "tmux.conf" "" else "${dotfiles}/tmux.conf";
in
pkgs.mkShell {
  inherit name;
  packages = devEnv.packages ++ [ pkgs.zsh ];

  shellHook = ''
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: ''export ${k}="${v}"'') devEnv.env)}
    export ZDOTDIR=${zdotdir}
    export TMUX_CONF=${tmuxConf}

    # tmux started from here picks up the same configuration.
    tmux() { command tmux -f "$TMUX_CONF" "$@"; }

    # `nix develop` runs bash; hand over to zsh unless something already did,
    # or unless a command was passed with -c (which must not be swallowed).
    if [ -z "$IN_NIX_DEV_ZSH" ] && [ -t 0 ] && [ -z "$__NIX_DEV_COMMAND" ]; then
      export IN_NIX_DEV_ZSH=1
      exec ${lib.getExe pkgs.zsh}
    fi
  '';
}
