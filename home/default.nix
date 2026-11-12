# Every home-manager module in this repository. Nothing in here reads
# `osConfig`; system/home.nix passes in what the modules need.
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

    ./git.nix
    ./editor/neovim.nix

    ./desktop/i3.nix
    ./desktop/statusbar.nix
    ./desktop/battery.nix
    ./desktop/idle.nix
    ./desktop/display.nix
    ./desktop/gtk.nix
    ./desktop/wallpaper.nix
    ./desktop/picom.nix
    ./desktop/dunst.nix
    ./desktop/ghostty.nix
    ./desktop/flameshot.nix
    ./desktop/vicinae.nix
    ./desktop/network.nix
    ./desktop/dock.nix
    ./desktop/bluetooth-headphones.nix
    ./desktop/easy-boot.nix
    ./desktop/laptop-speakers.nix
    ./desktop/jbl-speaker.nix

    ./dev/toolchains.nix
    ./dev/agents.nix
    ./dev/claude-plugins.nix
    ./dev/pi.nix
  ];

  # Both live in this repository, so the store path is this flake's source.
  nixstart.home.dotfiles = lib.mkDefault "${self}/dotfiles";
  nixstart.home.wallpapers = lib.mkDefault "${self}/wallpapers";

  home.username = config.nixstart.home.user.name;
  home.homeDirectory = "/home/${config.nixstart.home.user.name}";

  xdg.enable = true;

  programs.home-manager.enable = true;
}
