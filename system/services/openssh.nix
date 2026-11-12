# Key-only SSH.
{ config, lib, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = lib.mkDefault false;
      PermitRootLogin = lib.mkDefault "no";
    };
  };

  # Keys allowed in from other devices. NixOS writes these to
  # /etc/ssh/authorized_keys.d, which sshd reads alongside
  # ~/.ssh/authorized_keys, so a reinstall or a fresh /home keeps them.
  users.users.${config.nixstart.system.user.name}.openssh.authorizedKeys.keys = [
    # The Herdr phone app, which reaches herdr-core over SSH.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIImA9L6bz15e2sGvRgeBAT0MbWLit9Ovkn1zpmFb89V5 herdr-mobile"
  ];
}
