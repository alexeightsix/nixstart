# The `nixstart.system.*` namespace — what a machine *is*.
#
# The bootstrap stages encoded this as "which script did you remember to run";
# there was no way to ask a machine what it was supposed to be. This is that
# answer, and it covers only the system layer: boot, hardware, daemons, and
# the packages that belong to the machine rather than to a person. Everything
# a user carries with them is `nixstart.home.*`, in home/options.nix, which
# is a separate module set that can be applied to a machine this repository
# does not manage at all.
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
          Groups on top of the ones the enabled modules add themselves.
          stage-02, stage-07 and stage-09 each ran their own `usermod -aG`, so
          the real group list only existed as the union of three scripts you
          had to have run in the right order.
        '';
      };
    };

    desktop.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        X11, i3 as a session, fonts, audio. Off by default, so a headless box
        gets what `link.sh --headless` used to give it without a second list
        to keep in step.
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
          Flathub as a declarative remote. Everything stage-04 installed this
          way is in nixpkgs now, so this is off unless something genuinely
          ships no other way.
        '';
      };
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
