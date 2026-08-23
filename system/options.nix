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
