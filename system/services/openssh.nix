# stage-02 ran `systemctl enable --now sshd` with the distro default config,
# which on Fedora permits password authentication.
{ lib, ... }:
{
  services.openssh = {
    enable = lib.mkDefault true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      PermitRootLogin = lib.mkDefault "no";
    };
  };
}
