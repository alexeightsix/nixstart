{
  lib,
  pkgs,
  ...
}:
{
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # Wired only: keep the wifi radio off on every boot. NetworkManager already
  # remembers `nmcli radio wifi off` in its state file, but that lives outside
  # this repo; this makes it part of the config. `nmcli radio wifi on` still
  # works for a one-off, until the next boot.
  systemd.services.wifi-radio-off = {
    description = "Turn the wifi radio off";
    after = [ "NetworkManager.service" ];
    requires = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe' pkgs.networkmanager "nmcli"} radio wifi off";
    };
  };

  # Accept everything arriving from a private address (10/8, 172.16/12,
  # 192.168/16, IPv6 ULA and link-local) rather than naming ports, so a phone
  # on the same network reaches Metro (8081), the local API and whatever comes
  # next without a rebuild each time.
  #
  # The cost: this is every private network the machine joins, cafe wifi
  # included, and behind it sit a bundler, an API, pgweb and Postgres on 5432.
  # Docker's bridges (172.17/16, 172.18/16) are covered too. tailscale0 is
  # already trusted, so a phone on the tailnet needs none of this. Only
  # inbound connections are affected.
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
  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -s 10.0.0.0/8 -j nixos-fw-accept
    iptables -A nixos-fw -s 172.16.0.0/12 -j nixos-fw-accept
    iptables -A nixos-fw -s 192.168.0.0/16 -j nixos-fw-accept
    ip6tables -A nixos-fw -s fc00::/7 -j nixos-fw-accept
    ip6tables -A nixos-fw -s fe80::/10 -j nixos-fw-accept
  '';

  environment.systemPackages = with pkgs; [
    nmap
    inetutils # `telnet`
    rclone
  ];
}
