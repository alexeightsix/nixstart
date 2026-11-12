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

    ./desktop/wm/i3.nix
    ./desktop/wm/statusbar.nix
    ./desktop/wm/picom.nix

    ./desktop/display/outputs.nix
    ./desktop/display/dock.nix
    ./desktop/display/wallpaper.nix

    ./desktop/power/battery.nix
    ./desktop/power/idle.nix
    ./desktop/power/easy-boot.nix

    ./desktop/audio/bluetooth-headphones.nix
    ./desktop/audio/laptop-speakers.nix
    ./desktop/audio/jbl-speaker.nix

    ./desktop/apps/ghostty.nix
    ./desktop/apps/vicinae.nix
    ./desktop/apps/flameshot.nix
    ./desktop/apps/dunst.nix
    ./desktop/apps/gtk.nix
    ./desktop/apps/network.nix

    ./dev/toolchains.nix
    ./dev/agents.nix
    ./dev/claude-plugins.nix
    ./dev/pi.nix
  ];

  # Both live in this repository, so the store path is this flake's source.
  nixstart.home.dotfiles = lib.mkDefault "${self}/dotfiles";
  nixstart.home.wallpapers = lib.mkDefault "${self}/assets/wallpapers";

  home.username = config.nixstart.home.user.name;
  home.homeDirectory = "/home/${config.nixstart.home.user.name}";

  xdg.enable = true;

  programs.home-manager.enable = true;
}
