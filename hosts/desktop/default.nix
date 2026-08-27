# The workstation.
#
# A host file is the facts that are true of this machine and no other.
# Everything else is a decision recorded in system/options.nix and home/options.nix.
{ ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "desktop";

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

    # Everything: this is the machine that runs the disposable dev instances
    # and the occasional full VM.
    virtualisation = {
      docker = true;
      libvirt = true;
      incus = true;
    };

    hardware = {
      keychron = true;
      rgb = true; # the Fury Renegade RAM, held at zero brightness
      bluetooth = true;
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
    desktop.weather.enable = true;
    desktop.weather.location = "Montreal";
    desktop.statusBar = "desktop";

    # scripts/xrandr.sh, which was one commented-out line for every machine.
    #
    # --primary is load-bearing beyond xrandr: weather-wallpaper-fit finds the
    # screen geometry with `awk '/ connected primary/'`, and with no output
    # flagged it silently fell back to the uncropped base image, which feh then
    # cropped itself — taking the temperature off the right edge. That is the
    # cut-off text on this host; the laptop was unaffected because dock.nix
    # always flags one. See home/desktop/wallpaper.nix.
    desktop.monitors = ''
      xrandr --output eDP-1 --off \
             --output DP-1 --off \
             --output HDMI-1 --off \
             --output DP-2 --off \
             --output HDMI-2 --primary --mode 1920x1080 --pos 0x0 --rotate normal
    '';

    languages = [
      "go"
      "node"
      "php"
      "rust"
      "lua"
      "python"
      "gtk" # gtk4 + libadwaita + blueprint-compiler, from stage-01
    ];
    databases = true; # the `mysql` and `psql` clients
    agents = true;
  };
}
