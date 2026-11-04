# Tailscale.
{
  config,
  ...
}:
{
  services.tailscale = {
    enable = true;
    # "client" opens the UDP port and sets up the routing a normal node
    # needs. Change to "both" or "server" if this machine ever advertises
    # routes or runs as an exit node.
    useRoutingFeatures = "client";
    openFirewall = true;

    # Lets the user run `tailscale up`/`status` without sudo. Reasserted on
    # every boot by nixpkgs' `tailscaled-set` oneshot.
    extraSetFlags = [ "--operator=${config.nixstart.system.user.name}" ];
  };

  # Let the daemon's own DNS handling through; without this, MagicDNS
  # resolution breaks whenever the firewall is on.
  networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
}
