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

  home-manager.users.alex.nixstart.home = {
    checkout = "/home/alex/kickstart";

    user.email = "alexlatour@gmail.com";
    desktop.weather.enable = true;
    desktop.weather.location = "Montreal";
    desktop.statusBar = "desktop";

    # scripts/xrandr.sh, which was one commented-out line for every machine.
    desktop.monitors = ''
      xrandr --output eDP-1 --off \
             --output DP-1 --off \
             --output HDMI-1 --off \
             --output DP-2 --off \
             --output HDMI-2 --mode 1920x1080 --pos 0x0 --rotate normal
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
