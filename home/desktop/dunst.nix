# Notifications.
#
# dotfiles/dunstrc is installed as-is rather than re-typed into `settings`;
# the home-manager module still runs the service.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  services.dunst.enable = true;

  # The module writes dunstrc from `settings`; with none set it writes an
  # empty file, so the tracked one replaces it here. mkForce because both
  # definitions target the same path.
  xdg.configFile."dunst/dunstrc" = lib.mkForce {
    source = "${cfg.dotfiles}/dunstrc";
  };

  # dunstrc asks for "JetBrains Mono 10" and icon lookup; neither works
  # without the font and an icon theme actually installed.
  home.packages = with pkgs; [
    libnotify
    adwaita-icon-theme
  ];
}
