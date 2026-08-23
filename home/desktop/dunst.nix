# Notifications.
#
# dunstrc was in the repository but link.sh never linked it — it is not in
# either the shared or the desktop list — so the file has been tracked and
# unused. Wiring it up is part of the port, not a change of behaviour.
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
    services.dunst = {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          follow = "mouse";
          width = 320;
          height = "(0, 120)";
          origin = "top-right";
          offset = "(20, 20)";
          scale = 0;
          transparency = 15;

          font = "JetBrains Mono 10";
          line_height = 4;
          padding = 10;
          horizontal_padding = 10;
          frame_width = 2;
          frame_color = "#bd93f9";
          corner_radius = 8;

          timeout = 5;
          separator_height = 2;
          separator_color = "#44475a";
          mouse_left_click = "close_current";
          mouse_middle_click = "do_action";
          mouse_right_click = "close_all";

          markup = "full";
        };
      };
    };
  };
}
