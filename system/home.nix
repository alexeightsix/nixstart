# The bridge from the system layer to the home layer.
#
# One-directional and explicit: the system tells the home modules what this
# machine is, and the home modules never read `osConfig`.
{ config, ... }:
let
  cfg = config.nixstart.system;
in
{
  home-manager.users.${cfg.user.name} = {
    imports = [ ../home ];

    nixstart.home = {
      user.name = cfg.user.name;
      user.fullName = cfg.user.fullName;
    };

    home.stateVersion = config.system.stateVersion;
  };
}
