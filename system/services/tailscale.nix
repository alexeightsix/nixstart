# Tailscale.
#
# It is running on this machine today and no bootstrap stage installs it —
# `tailscale0` shows up in `incus list` output but nothing in the repository
# put it there, so a rebuilt machine would silently come back without the
# tailnet. That is exactly the class of thing this port is for.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.nixstart.system.tailscale = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Tailscale daemon, and the CLI.";
  };

  config = lib.mkIf config.nixstart.system.tailscale {
    services.tailscale = {
      enable = true;
      # "client" opens the UDP port and sets up the routing a normal node
      # needs. Change to "both" or "server" if this machine ever advertises
      # routes or runs as an exit node.
      useRoutingFeatures = "client";
      openFirewall = true;

      # `sudo tailscale set --operator=$USER`, which otherwise has to be run
      # by hand after every install and is forgotten after every reinstall.
      # Without it `tailscale up`, `tailscale status` and friends all need
      # sudo: the daemon only takes control commands from root or from the
      # one account named as its operator.
      #
      # nixpkgs turns this list into a `tailscaled-set` oneshot, ordered
      # after tailscaled and wanted by multi-user.target, so it is reasserted
      # on every boot and every activation instead of being a one-time manual
      # step. It follows the host's user rather than hardcoding a name.
      extraSetFlags = [ "--operator=${config.nixstart.system.user.name}" ];
    };

    # Let the daemon's own DNS handling through; without this, MagicDNS
    # resolution breaks whenever the firewall is on.
    networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];

    environment.systemPackages = [ pkgs.tailscale ];
  };
}
