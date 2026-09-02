# GTK, which on this desktop means Thunar and the occasional dialog.
#
# Everything else was already Rose Pine — Ghostty's `theme`, the i3 bar,
# vicinae, glow — and GTK was the one surface still on stock Adwaita, which a
# file manager is exactly the application to make impossible to ignore.
#
# The icons are nixpkgs' `rose-pine-icon-theme`: Papirus recoloured, so the
# coverage is Papirus' rather than a hand-drawn set that falls back to a
# missing-image glyph the first time it meets an unusual mime type. It
# inherits breeze and hicolor, and adwaita-icon-theme stays installed under
# it as the last resort.
#
# The cursor is deliberately not set here. home/desktop/display.nix owns it,
# because its size is a HiDPI decision rather than a colour one.
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
  config = lib.mkIf cfg.desktop.enable {
    gtk = {
      enable = true;

      theme = {
        # The one variant pkgs/rose-pine-gtk-theme builds — see the comment
        # there for why the whole matrix is not installed.
        name = "Rosepine-Dark";
        package = pkgs.rose-pine-gtk-theme;
      };

      iconTheme = {
        # The directory name. The theme's own `Name=` reads "oomox-rose-pine",
        # an artefact of the generator upstream used, and is not what GTK
        # looks up.
        name = "rose-pine";
        package = pkgs.rose-pine-icon-theme;
      };

      # home-manager is changing this default to null, on the grounds that a
      # GTK 3-era theme name usually means nothing to GTK 4. This one is not
      # in that category — it ships a real gtk-4.0 stylesheet — so the answer
      # is the old default, stated explicitly rather than inherited from a
      # stateVersion of "25.05".
      gtk4.theme = config.gtk.theme;

      # Naming the dark variant is not enough on its own: a GTK application
      # that ships light and dark stylesheets of its own picks between them
      # from this, not from the theme name.
      gtk3.extraConfig.gtk-application-prefer-dark-theme = true;
      gtk4.extraConfig.gtk-application-prefer-dark-theme = true;
    };

    # The same answer again for anything that asks the XDG portal instead —
    # GTK 4 and libadwaita applications read the portal, not settings.ini.
    dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
