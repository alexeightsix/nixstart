# Resolution, scaling and outputs.
#
# i3's and Ghostty's font sizes are point sizes, so they follow DPI on their
# own and nothing here touches them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  desktop = cfg.desktop;
in
{
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
}
