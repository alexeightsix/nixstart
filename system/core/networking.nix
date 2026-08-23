{ lib, pkgs, ... }:
{
  networking.networkmanager.enable = lib.mkDefault true;
  networking.firewall.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    nmap
    inetutils # `telnet`, which Fedora ships as its own package
    rsync
    rclone
  ];
}
