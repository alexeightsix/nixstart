# Dell XPS 13 9350 — Core Ultra 7 258V, Arc 140V, 32GB LPDDR5X, Killer BE201.
{ ... }:
{
  imports = [
    ./hardware/hardware-configuration.nix
    ./easy-boot-flag.nix
  ];

  networking.hostName = "laptop";

  nixstart.system = {
    user.name = "alex";

    # First-boot password only, and world-readable in the store — run
    # `passwd` on the first login and this is ignored from then on. Replace it
    # with a `user-password` secret in secrets/HOSTNAME.yaml when sops is set
    # up; that wins over this whenever it exists.
    user.initialPassword = "changeme";
  };

  home-manager.users.alex.nixstart.home = {
    checkout = "/home/alex/nixstart";
    user.email = "alexlatour@gmail.com";

    desktop = {
      weather.enable = true;
      weather.location = "Montreal";

      # wallpaper-6 is a pale cream sky where the temperature sits, so the
      # white-over-black pair that suited wallpaper-5 is carried entirely by
      # its drop shadow and is hard to read at a glance. Inverted: dark brown
      # on cream, which is the same two colours the image already uses.
      weather.textColor = "#2b1410";
      weather.shadowColor = "#f8e4c8";

      # No fixed xrandr line: this machine gets docked and undocked, so the
      # layout follows what is actually plugged in.
      autorandr = true;

      # One keypress moves both screens. $mod+1 puts the monitor on workspace
      # 1 and the panel on its half of the pair, which the bar renders as 1
      # too — rather than i3's default, where $mod+1 jumps focus to whichever
      # screen already holds workspace 1 and leaves the other one alone.
      pairedWorkspaces = true;

      # One bar, on the monitor while one is connected and on the panel when
      # it is not. i3 resolves "primary" against the X primary flag, and
      # `dock` below marks exactly one output primary in each of its two
      # branches, so this follows the dock without naming a connector. The
      # cost: nothing on the panel says which workspace it is showing.
      barOutputs = [ "primary" ];

      # The agent terminal lives on the panel while supervising happens on
      # the monitor. $mod+Shift+a toggles it (off at every login); $mod+0 is
      # left out of it. See home/desktop/agent-mode.nix.
      agentMode.enable = true;

      # autorandr alone is not enough: with no saved profiles it matches
      # nothing, and home-manager's unit only fires at login. See
      # home/desktop/dock.nix.
      dock = {
        enable = true;
        internal = "eDP-1"; # `xrandr --query` on this machine
        # An external display extends onto the panel rather than replacing
        # it, each at its own mode. internalPosition is where the panel
        # physically sits on the desk (under the monitor, centred), so the
        # pointer crosses where the screens actually meet.
        keepInternal = true;
        internalPosition = "below";

        # Driven below native to enlarge text, and only here: the panel is
        # 169dpi against the monitor's 81dpi, and `dpi` is Xft.dpi, which is
        # global — raising it would grow text on the monitor too. 1680x1050
        # keeps the panel's 16:10, so nothing stretches.
        internalMode = "1680x1050";
      };

      # The 9350 ships with FHD+ (1920x1200), QHD+ (2560x1600) or 2.8K OLED
      # (2880x1800) and the invoice does not say which. 1920x1200 on 13.4" is
      # ~169dpi, which is already past the point where 96 looks wrong — but
      # X's own detection is close enough there, so this stays null until the
      # panel is confirmed with `xrandr --query`.
      #
      #   FHD+  1920x1200 -> leave null
      #   QHD+  2560x1600 -> dpi = 144
      #   2.8K  2880x1800 -> dpi = 168, and GDK_SCALE kicks in
      dpi = null;
      cursorSize = 24;
    };

    languages = [
      "go"
      "node"
      "python"
      "rust"
      "lua"

      # The Expo project in ~/dev/spotlight.
      "android"
    ];
    databases = true;
    agents = true;
  };
}
