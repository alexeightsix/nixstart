# The `nixstart.system.*` namespace — what a machine is.
#
# The system layer only: boot, hardware, daemons, and the packages that belong
# to the machine rather than to a person. Everything a user carries with them
# is `nixstart.home.*`, in home/options.nix, which is a separate module set
# that can be applied to a machine this repository does not manage at all.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.nixstart.system = {

    user = {
      name = mkOption {
        type = types.str;
        default = "alex";
        description = "The human account this machine is set up for.";
      };
      fullName = mkOption {
        type = types.str;
        default = "Alexander Latour";
        description = "Description on the account.";
      };
      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Groups on top of the ones the enabled modules add themselves. Each
          module that needs a group declares it, so the real list is derived
          rather than maintained here.
        '';
      };
    };

    desktop.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        X11, i3 as a session, fonts, audio. Off by default, so a headless
        machine gets nothing graphical without a second list to keep in step.
      '';
    };

    apps = {
      gui = mkOption {
        type = types.bool;
        default = false;
        description = "Browsers, chat, media, database and design tools.";
      };
      flatpak = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Flathub as a declarative remote, for applications that ship no other
          way. Everything currently installed is in nixpkgs, so this is off.
        '';
      };
    };

    trustLocalNetwork = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Accept everything arriving from a private address — 10/8, 172.16/12,
        192.168/16, and IPv6 ULA and link-local — rather than naming ports.

        This is what makes developing against real hardware workable. A phone
        running the app needs the Metro bundler on 8081 and the local API on
        6969, and the next thing tried needs the frontend on 6173, or pgweb,
        or a port that does not exist yet; each one is a rebuild, and each
        failure looks the same from the phone — a request that hangs rather
        than one that is refused, because the firewall drops rather than
        rejects. A port list turns a day of that into a day of edits here.

        What it gives up is real and worth being plain about. This is not "the
        home network": it is every private network the machine ever joins, and
        on cafe wifi the other customers are inside 192.168/16 too. Behind it
        on this machine sit a bundler serving the project's source, an API,
        pgweb, and Postgres on 5432 — none of which are written to be exposed
        to strangers. Docker's own bridges live in 172.17/16 and 172.18/16 and
        so are covered by this as well.

        Tailscale is the version of this with none of that cost: tailscale0 is
        already a trusted interface, so a phone on the tailnet reaches every
        one of these ports on 100.x with the firewall untouched, on any
        network, with no rule here at all. Prefer it where the phone can be
        enrolled; this option is for the phone that cannot.

        Outbound traffic and established connections are unaffected either
        way — this only changes what may start a connection *to* this machine.
      '';
    };

    hardware = {
      keychron = mkOption {
        type = types.bool;
        default = false;
        description = "hidraw access for the Keychron K2 Pro, so VIA can flash it.";
      };
      rgb = mkOption {
        type = types.bool;
        default = false;
        description = "Hold the RAM RGB at zero brightness on every boot.";
      };
      bluetooth = mkOption {
        type = types.bool;
        default = false;
        description = "Bluetooth stack and the blueman tools.";
      };
    };
  };
}
