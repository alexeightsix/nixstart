# Machine-local secrets, encrypted to the host key so they can live in this
# repository. Inert until secrets/<hostname>.yaml exists.
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
      };
    };
  };
}
