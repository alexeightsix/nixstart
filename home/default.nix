# Every home-manager module in this repository.
#
# Importing this one imports the lot; each is inert until the matching
# `kickstart.home.*` option is set, so a profile is a list of decisions rather
# than a list of imports. Nothing in here reads `osConfig`, which is what lets
# the same modules configure an account on a machine NixOS does not manage.
{
  config,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./options.nix

    ./shell/zsh.nix
    ./shell/aliases.nix
    ./shell/atuin.nix
    ./shell/tools.nix
    ./shell/tmux.nix
    ./shell/zellij.nix

    ./git.nix
    ./editor/neovim.nix

    ./desktop/i3.nix
    ./desktop/statusbar.nix
    ./desktop/picom.nix
    ./desktop/dunst.nix
    ./desktop/ghostty.nix
    ./desktop/flameshot.nix
    ./desktop/vicinae.nix

    ./dev/toolchains.nix
    ./dev/agents.nix
    ./dev/pi.nix
  ];

  # The store path comes from the flake input; a profile or host can still
  # override it (--override-input, or a checkout on a machine with no network).
  kickstart.home.dotfiles = lib.mkDefault "${inputs.dotfiles}/dotfiles";
  kickstart.home.wallpapers = lib.mkDefault "${inputs.dotfiles}/wallpapers";

  home.username = config.kickstart.home.user.name;
  home.homeDirectory = "/home/${config.kickstart.home.user.name}";

  # `home.file` and `xdg.configFile` replace link.sh's link()/preserve()/
  # render(). Anything already at a destination is moved aside — the same
  # courtesy preserve() was doing with a timestamp — and the sed pass that
  # substituted $HOME, $DOTFILES and $KICKSTART into formats with no variables
  # of their own is just string interpolation now.
  xdg.enable = true;

  programs.home-manager.enable = true;
}
