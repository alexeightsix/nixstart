{
  config,
  lib,
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = lib.mkDefault true;
  networking.firewall.enable = lib.mkDefault true;

  # Trust the private networks this machine is on, rather than listing ports.
  # Off unless a host asks for it; see the option in system/options.nix for
  # what that exposes and for the Tailscale version that exposes nothing.
  #
  # extraCommands and not extraInputRules: the latter is read only by the
  # nftables backend, and this machine is on iptables, where it is accepted as
  # a valid option and then silently does nothing.
  #
  # Appending is correct here. The module emits its own rules first, runs
  # extraCommands, and only then appends the `-j nixos-fw-log-refuse` that
  # ends the chain — so these land ahead of the catch-all rather than after
  # it, where they would never be reached. `iptables` and `ip6tables` are the
  # module's own helpers, already carrying -w.
  networking.firewall.extraCommands = lib.mkIf config.nixstart.system.trustLocalNetwork ''
    iptables -A nixos-fw -s 10.0.0.0/8 -j nixos-fw-accept
    iptables -A nixos-fw -s 172.16.0.0/12 -j nixos-fw-accept
    iptables -A nixos-fw -s 192.168.0.0/16 -j nixos-fw-accept
    ip6tables -A nixos-fw -s fc00::/7 -j nixos-fw-accept
    ip6tables -A nixos-fw -s fe80::/10 -j nixos-fw-accept
  '';

  environment.systemPackages = with pkgs; [
    nmap
    inetutils # `telnet`, which Fedora ships as its own package
    rsync
    rclone
  ];
}
