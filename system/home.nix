# The bridge from the system layer to the home layer.
#
# One-directional and explicit: the system knows the home modules exist and
# tells them what this machine is. The home modules never read `osConfig`,
# which is the whole point — the same set configures an account on a machine
# this repository does not manage.
{ config, lib, ... }:
let
  cfg = config.kickstart.system;
in
{
  home-manager.users.${cfg.user.name} = {
    imports = [ ../home ];

    kickstart.home = {
      user.name = cfg.user.name;
      user.fullName = cfg.user.fullName;
      desktop.enable = lib.mkDefault cfg.desktop.enable;
    };

    home.stateVersion = config.system.stateVersion;
  };
}
