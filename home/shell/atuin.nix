# Shell history.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  atuin = config.programs.atuin;

  # The init script, generated once rather than by the integration's
  # `eval "$(atuin init zsh ...)"` on every shell. It depends only on the
  # atuin version and the flags, not on settings or history, so the build
  # needs nothing but a scratch HOME. The session id it asks `atuin uuid`
  # for is still minted per shell, by the script itself.
  atuinInit = pkgs.runCommand "atuin-init.zsh" { } ''
    HOME=$TMPDIR ${lib.getExe atuin.package} init zsh ${lib.escapeShellArgs atuin.flags} > $out
  '';
in
{
  programs.atuin = {
    enable = true;
    enableZshIntegration = false;
    flags = [ "--disable-up-arrow" ];
    settings = {
      style = "compact";
      show_preview = true;
      show_help = false;
      show_tabs = false;
      ai.enabled = true;
      ai.model = "max";
    };
  };

  # The same guard the integration uses: atuin's widgets need the line editor.
  programs.zsh.initContent = lib.mkOrder 1000 ''
    if [[ $options[zle] = on ]]; then
      source ${atuinInit}
    fi
  '';
}
