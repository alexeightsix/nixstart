# Machine-local secrets.
#
# Today these are untracked plaintext files that every script re-implements a
# reader for: ~/.zsh_secrets, ~/.config/sync-dev/host, ~/.config/sync-dev/password
# (mode 600, with a comment explaining that publishing the host next to "logs
# in as root over password auth" is a target). Encrypted to the host key, they
# can live in this repository.
{
  config,
  inputs,
  lib,
  ...
}:
let
  cfg = config.nixstart.system;
  secretsFile = ../../secrets/${config.networking.hostName}.yaml;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  config = lib.mkIf (builtins.pathExists secretsFile) {
    sops = {
      defaultSopsFile = secretsFile;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets = {
        # The login password, as a hash from `mkpasswd -m yescrypt`. Read by
        # system/core/users.nix in preference to any initialPassword.
        user-password.neededForUsers = true;

        zsh-secrets = {
          owner = cfg.user.name;
          path = "/home/${cfg.user.name}/.zsh_secrets";
        };
        sync-dev-host = {
          owner = cfg.user.name;
          path = "/home/${cfg.user.name}/.config/sync-dev/host";
        };
        sync-dev-password = {
          owner = cfg.user.name;
          mode = "0600";
          path = "/home/${cfg.user.name}/.config/sync-dev/password";
        };
      };
    };
  };
}
