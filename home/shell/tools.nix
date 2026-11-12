# The small shell tools.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  # `zoxide init zsh` prints the same script every time for a given zoxide,
  # so it is generated once here and sourced, rather than the integration's
  # `eval "$(zoxide init zsh)"` starting zoxide on every shell.
  zoxideInit = pkgs.runCommand "zoxide-init.zsh" { } ''
    ${lib.getExe config.programs.zoxide.package} init zsh > $out
  '';
in
{
  # A store symlink rather than seeded like flameshot.ini: lazydocker
  # rewrites this file with its full defaults on exit, and the read-only
  # store path is what makes that write fail and keeps the setting.
  xdg.configFile."lazydocker/config.yml".source = "${cfg.dotfiles}/lazydocker/config.yml";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
  };
  programs.zsh.initContent = lib.mkOrder 1000 "source ${zoxideInit}";

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    # Atuin owns Ctrl-R; this stops the two modules fighting over the key.
    historyWidget.zsh.command = "";
  };

  programs.bat.enable = true;
  programs.eza.enable = true;
}
