# Every home-manager module in this repository.
#
# Importing this one imports the lot; each is inert until the matching
# `nixstart.home.*` option is set, so a profile is a list of decisions rather
# than a list of imports. Nothing in here reads `osConfig`, which is what lets
# the same modules configure an account on a machine NixOS does not manage.
{
  config,
  lib,
  self,
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

    ./git.nix
    ./editor/neovim.nix

    ./desktop/i3.nix
    ./desktop/jk.nix
    ./desktop/statusbar.nix
    ./desktop/battery.nix
    ./desktop/display.nix
    ./desktop/gtk.nix
    ./desktop/wallpaper.nix
    ./desktop/picom.nix
    ./desktop/dunst.nix
    ./desktop/ghostty.nix
    ./desktop/flameshot.nix
    ./desktop/vicinae.nix
    ./desktop/dock.nix

    ./dev/toolchains.nix
    ./dev/agents.nix
    ./dev/claude-plugins.nix
    ./dev/pi.nix
  ];

  # Both live in this repository now, so the store path is this flake's own
  # source. A profile or host can still override either.
  nixstart.home.dotfiles = lib.mkDefault "${self}/dotfiles";
  nixstart.home.wallpapers = lib.mkDefault "${self}/wallpapers";

  home.username = config.nixstart.home.user.name;
  home.homeDirectory = "/home/${config.nixstart.home.user.name}";

  # `home.file` and `xdg.configFile` replace link.sh's link()/preserve()/
  # render(). Anything already at a destination is moved aside — the same
  # courtesy preserve() was doing with a timestamp — and the sed pass that
  # substituted $HOME, $DOTFILES and $KICKSTART into formats with no variables
  # of their own is just string interpolation now.
  xdg.enable = true;

  programs.home-manager.enable = true;
}
