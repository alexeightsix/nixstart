# The `nixstart.system.*` namespace: the account this machine is set up for.
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

  };
}
