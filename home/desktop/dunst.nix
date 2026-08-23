# Notifications.
#
# dunstrc was tracked in the repository and link.sh never linked it — it is in
# neither the shared nor the desktop list — so the file has sat there unused
# and every notification has been rendered with dunst's built-in defaults.
#
# The tracked file is the configuration, not a transcription of it into Nix
# attributes: it is a complete dunstrc with [icons] and three urgency sections,
# and re-typing it as an attrset would create a second copy to keep in step
# with the first. home-manager's `settings` option is bypassed for that reason
# and the file is installed directly; the module is still what runs the
# service, so `systemctl --user status dunst` behaves normally.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
in
{
  config = lib.mkIf cfg.desktop.enable {
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
  };
}
