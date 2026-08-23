# The terminal.
#
# The config is a flat key = value list, which is exactly what
# `programs.ghostty.settings` takes — including the repeated `font-feature`
# and `keybind` keys, as lists.
#
# The two Enter keybinds are load-bearing and the reason they exist is worth
# keeping: Ghostty reports modified keys through the kitty keyboard protocol
# and tmux asks for them the older xterm way, which Ghostty does not
# implement. Neither side is wrong; they simply never agree, so tmux receives
# a plain Enter. Sending the escape sequence directly sidesteps the
# negotiation.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
  shader = cfg.desktop.ghosttyShader;
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;

      settings = {
        app-notifications = "no-clipboard-copy";

        background-blur = 10;
        background-opacity = 0.95;

        clipboard-paste-protection = false;
        clipboard-trim-trailing-spaces = true;
        confirm-close-surface = true;
        copy-on-select = "clipboard";

        cursor-style = "bar";
        cursor-style-blink = false;

        font-family = "JetBrainsMono Nerd Font";
        font-feature = [
          "-dlig"
          "-calt"
          "-liga"
        ];
        font-size = 10;

        gtk-tabs-location = "bottom";
        gtk-wide-tabs = false;

        minimum-contrast = 1.1;
        mouse-hide-while-typing = true;

        quit-after-last-window-closed = true;
        quit-after-last-window-closed-delay = "15s";

        scrollback-limit = 10000000;
        shell-integration-features = "no-cursor";
        theme = "Rose Pine";

        window-decoration = false;
        window-padding-balance = true;
        window-padding-x = 1;
        window-padding-y = 1;
        window-save-state = "always";
        window-theme = "ghostty";

        # Absolute store path rather than ~/.config/ghostty/bloom.glsl: the
        # shader and the line that names it then move together, and a machine
        # that has never had the file copied into place still gets it.
        custom-shader = lib.mkIf (shader != null) "${cfg.dotfiles}/ghostty-shaders/${shader}.glsl";

        keybind = [
          "ctrl+shift+slash=start_search"
          "shift+enter=text:\\x1b[13;2u"
          "ctrl+enter=text:\\x1b[13;5u"
        ];
      };
    };

    # Both tracked shaders are installed, not just the selected one, so
    # switching is an option change rather than a file copy.
    xdg.configFile = {
      "ghostty/shaders/bloom.glsl".source = "${cfg.dotfiles}/ghostty-shaders/bloom.glsl";
      "ghostty/shaders/water.glsl".source = "${cfg.dotfiles}/ghostty-shaders/water.glsl";
    };
  };
}
