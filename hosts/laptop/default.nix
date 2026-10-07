# Dell XPS 13 9350 — Core Ultra 7 258V, Arc 140V, 32GB LPDDR5X, Killer BE201.
#
# scripts/i3status-select.sh existed to tell this machine and the desktop
# apart at runtime, by testing for /sys/class/power_supply/BAT0. This is that
# test, answered once, plus everything else that is only true of a laptop.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "laptop";

  nixstart.system = {
    user.name = "alex";

    # First-boot password only, and world-readable in the store — run
    # `passwd` on the first login and this is ignored from then on. Replace it
    # with a `user-password` secret in secrets/HOSTNAME.yaml when sops is set
    # up; that wins over this whenever it exists.
    user.initialPassword = "changeme";

    desktop.enable = true;
    apps.gui = true;
    tailscale = true;

    # Containers only. Full VMs belong on the desktop, not on something
    # running off a 60W charger.
    virtualisation.docker = true;

    # Reachable from a phone on the same network: Metro, the local API, and
    # whatever the next thing turns out to be. This is the machine the Expo
    # project is developed on and testing it on real hardware is the point —
    # see `languages = [ ... "android" ]` below.
    trustLocalNetwork = true;

    hardware = {
      xps13 = true; # Lunar Lake: kernel, Xe2, SOF audio, fprintd, upower
      keychron = true;
      bluetooth = true;
      # No RGB — that is the desktop's RAM.
    };
  };

  # /home only — the system is a generation and rolls back from the boot
  # menu; /home is the part that does not.
  nixstart.system.snapshots.home = true;

  # The two configurations that stay working checkouts rather than store paths.
  # Both options default to off, on the reasoning "link it yourself once with
  # ln -s and Nix never touches the directory" — but nobody ever did, so
  # ~/.config/nvim did not exist at all and neovim ran with no configuration
  # despite dotfiles/nvim being fully ported, and ~/.pi did not exist either.
  # Turning them on makes activation keep both links in place.
  home-manager.users.alex.nixstart.neovim.linkConfig = true;
  home-manager.users.alex.nixstart.pi.linkConfig = true;

  home-manager.users.alex.nixstart.home = {
    checkout = "/home/alex/nixstart";
    user.email = "alexlatour@gmail.com";

    desktop = {
      weather.enable = true;
      weather.location = "Montreal";

      # No fixed xrandr line: this machine gets docked and undocked, so the
      # layout follows what is actually plugged in.
      autorandr = true;

      # One bar, on the monitor while there is one, on the panel when there
      # is not. With no `output` at all i3 draws a bar on every screen, so
      # docked there were two of them — the status line duplicated on the
      # panel below the monitor showing the same clock and the same battery.
      #
      # "primary" rather than naming DP-1: `dock` below already marks exactly
      # one output primary in each of its two branches — the first external
      # when docked, the panel when undocked — which is precisely the rule
      # wanted here, and it holds for a monitor this machine has not met.
      barOutputs = [ "primary" ];

      # Laptop only — the desktop drives a single monitor and has no built-in
      # panel to switch off, so it leaves this at its default of false.
      #
      # autorandr alone was not enough: with no saved profiles it matches
      # nothing and does nothing, and home-manager's unit only fires at login.
      # See home/desktop/dock.nix.
      dock = {
        enable = true;
        internal = "eDP-1"; # `xrandr --query` on this machine
        # An external display extends onto the panel rather than replacing it:
        # both stay on, the first external is primary at +0+0 and the panel
        # sits to its right, each at its own native mode — DP-1 keeps 144Hz at
        # 1920x1080 and the panel keeps 1920x1200, which a mirrored layout
        # could not do.
        #
        # internalPosition is load-bearing now rather than aspirational, and
        # it describes where the panel physically is, not a preference: the
        # laptop sits under the monitor on this desk, centred on it, so the
        # pointer crosses between the two where the screens actually meet.
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

      # The Expo project in ~/dev/spotlight. This is the machine it is built
      # on, and it is the only one — the desktop does not have it, so the SDK
      # and its system image are not in that machine's closure.
      "android"
    ];
    databases = true;
    agents = true;
  };
}
