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
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  shader = cfg.desktop.ghosttyShader;
in
{
  config = lib.mkIf cfg.desktop.enable {
    programs.ghostty = {
      enable = true;
      enableZshIntegration = true;

      # main, pinned by revision in flake.nix, rather than the tagged release
      # in nixpkgs. home/desktop/i3.nix binds $mod+Return to this same
      # attribute rather than pkgs.ghostty, so the terminal i3 opens and the
      # one this configures cannot drift apart.
      package = inputs.ghostty.packages.${pkgs.stdenv.hostPlatform.system}.ghostty;

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

        # Ghostty's own tabs and splits, driven by the tmux bindings in
        # home/shell/tmux.nix so the muscle memory is one set of keys whether
        # or not a multiplexer is running. tmux window -> Ghostty tab,
        # tmux pane -> Ghostty split.
        #
        # The cost: while tmux IS running Ghostty eats ctrl+b before tmux sees
        # it, so the chords below win and tmux's own prefix bindings do not
        # fire. ctrl+b>b forwards a literal ctrl+b (0x02) for the tmux
        # bindings that have no Ghostty equivalent.
        keybind = [
          "ctrl+shift+slash=start_search"
          "shift+enter=text:\\x1b[13;2u"
          "ctrl+enter=text:\\x1b[13;5u"

          # Send the prefix itself through to tmux.
          "ctrl+b>b=text:\\x02"

          # Tabs (tmux windows). prefix+c, prefix+x, prefix+n, prefix+r.
          "ctrl+b>c=new_tab"
          "ctrl+b>x=close_surface"
          "ctrl+b>n=new_window"
          "ctrl+b>r=prompt_tab_title"
          "ctrl+b>tab=last_tab"

          # F1-F8 jump straight to a tab, as tmux binds them with -n.
          "f1=goto_tab:1"
          "f2=goto_tab:2"
          "f3=goto_tab:3"
          "f4=goto_tab:4"
          "f5=goto_tab:5"
          "f6=goto_tab:6"
          "f7=goto_tab:7"
          "f8=goto_tab:8"

          # Move the current tab, matching tmux's swap-window bindings.
          "ctrl+shift+left=move_tab:-1"
          "ctrl+shift+right=move_tab:1"

          # Splits (tmux panes). % splits right, " splits down, z zooms.
          "ctrl+b>shift+5=new_split:right"
          "ctrl+b>shift+apostrophe=new_split:down"
          "ctrl+b>z=toggle_split_zoom"

          # Focus a split: bare ctrl+hjkl the way vim-tmux-navigator does it,
          # and prefix+hjkl the way tmux.conf binds select-pane.
          "ctrl+h=goto_split:left"
          "ctrl+j=goto_split:bottom"
          "ctrl+k=goto_split:top"
          "ctrl+l=goto_split:right"
          "ctrl+b>h=goto_split:left"
          "ctrl+b>j=goto_split:bottom"
          "ctrl+b>k=goto_split:top"
          "ctrl+b>l=goto_split:right"

          # Resize, on both spellings tmux uses: shift+HJKL and ctrl+arrows.
          "ctrl+b>shift+h=resize_split:left,5"
          "ctrl+b>shift+j=resize_split:down,3"
          "ctrl+b>shift+k=resize_split:up,3"
          "ctrl+b>shift+l=resize_split:right,5"
          "ctrl+b>ctrl+left=resize_split:left,5"
          "ctrl+b>ctrl+down=resize_split:down,3"
          "ctrl+b>ctrl+up=resize_split:up,3"
          "ctrl+b>ctrl+right=resize_split:right,5"

          # Scrollback, as tmux's ctrl+up / ctrl+down copy-mode bindings.
          "ctrl+up=scroll_page_lines:-1"
          "ctrl+down=scroll_page_lines:1"
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
