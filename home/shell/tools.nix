# The small shell tools.
#
# .zshrc eval'd `atuin init zsh --disable-up-arrow` and `zoxide init zsh` by
# hand, each guarded with `command -v` because the same file is cloned into
# disposable Incus instances. The guard is unnecessary here: if the module is
# on, the binary is in the profile.
{ config, lib, ... }:
let
  cfg = config.nixstart.home;
in
{
  # link.sh linked lazydocker.yml to ~/.config/lazydocker/config.yml and the
  # port dropped it: system/virtualisation.nix installs the binary, but
  # nothing installed its configuration, so it ran with the default of
  # returning to the menu after every command instead of straight to the
  # container.
  #
  # Not `preserve`d like flameshot.ini — lazydocker rewrites this file with
  # its full default configuration on exit, which is why the tracked copy is
  # two lines and the written one is hundreds. A symlink into a read-only
  # store path makes that write fail, which is the behaviour that keeps the
  # setting.
  xdg.configFile."lazydocker/config.yml".source = "${cfg.dotfiles}/lazydocker.yml";

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;

    # Atuin owns Ctrl-R, as it does on Fedora today — .zshrc initialises atuin
    # after the oh-my-zsh fzf plugin, so atuin's binding wins there by order.
    # Saying so explicitly stops the two modules from fighting over the key.
    historyWidget.zsh.command = "";
  };

  programs.bat.enable = true;
  programs.eza.enable = true;
}
