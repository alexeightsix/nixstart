# The small shell tools.
#
# .zshrc eval'd `atuin init zsh --disable-up-arrow` and `zoxide init zsh` by
# hand, each guarded with `command -v` because the same file is cloned into
# disposable Incus instances. The guard is unnecessary here: if the module is
# on, the binary is in the profile.
{ lib, ... }:
{
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
