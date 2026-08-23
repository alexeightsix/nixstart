# Resolution, scaling and outputs.
#
# There were three separate gaps here, and they only show up on a laptop:
#
#   scripts/xrandr.sh   one commented-out line, so every machine ran an empty
#                       script at i3 start and no layout was ever applied
#   DPI                 never set anywhere, so X assumes 96dpi; correct at
#                       1920x1200, half-size at 2880x1800
#   cursor size         same, and the reason the pointer looks tiny on HiDPI
#
# i3config's `font pango:monospace 8` and Ghostty's `font-size = 10` are both
# point sizes, so they follow DPI automatically once it is right — they do not
# need to be changed per machine, which is why nothing here touches them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
  desktop = cfg.desktop;
in
{
  config = lib.mkIf desktop.enable {
    xresources.properties = lib.mkMerge [
      (lib.mkIf (desktop.dpi != null) {
        "Xft.dpi" = desktop.dpi;
      })
      {
        "Xft.antialias" = true;
        "Xft.hinting" = true;
        "Xft.hintstyle" = "hintslight";
        "Xft.rgba" = "rgb";
        "Xcursor.size" = desktop.cursorSize;
      }
    ];

    home.pointerCursor = {
      enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = desktop.cursorSize;
      x11.enable = true;
      gtk.enable = true;
    };

    # GTK applications scale by integer factor, not DPI, so a 2880x1800 panel
    # needs to be told separately from Xft.
    home.sessionVariables = lib.mkIf (desktop.dpi != null && desktop.dpi >= 168) {
      GDK_SCALE = 2;
      GDK_DPI_SCALE = "0.5";
      QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    };

    services.autorandr.enable = desktop.autorandr;
    home.packages = lib.optional desktop.autorandr pkgs.autorandr ++ [ pkgs.arandr ];
  };
}
