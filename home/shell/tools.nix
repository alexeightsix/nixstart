# The small shell tools.
{ config, ... }:
let
  cfg = config.nixstart.home;
in
{
  # A store symlink rather than seeded like flameshot.ini: lazydocker
  # rewrites this file with its full defaults on exit, and the read-only
  # store path is what makes that write fail and keeps the setting.
  xdg.configFile."lazydocker/config.yml".source = "${cfg.dotfiles}/lazydocker.yml";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    # Atuin owns Ctrl-R; this stops the two modules fighting over the key.
    historyWidget.zsh.command = "";
  };

  programs.bat.enable = true;
  programs.eza.enable = true;
}
