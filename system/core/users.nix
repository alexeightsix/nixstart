# The account, its password, and the groups the enabled modules need it in.
#
# stage-02, stage-07 and stage-09 each ran their own `usermod -aG`, so the
# group list only existed as the union of three scripts you had to have run.
#
# Passwords never came up in the old bootstrap because Fedora's installer had
# already asked for one. Nothing asks here, so a NixOS host with no password
# set produces an account that cannot log in at all: lightdm rejects an empty
# password, and sudo needs one because wheelNeedsPassword is on. Hence the
# two options below — one of them has to be set or the build fails.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.system;
  sops = config.sops.secrets or { };
  hasSopsPassword = sops ? user-password;
in
{
  options.nixstart.system.user.uid = lib.mkOption {
    type = lib.types.int;
    default = 1000;
    description = ''
      Pinned rather than left to be allocated. Every file in /home carries a
      numeric owner, so an account that comes back with a different uid owns
      none of them — and nothing warns you, the files simply belong to a
      stranger.
    '';
  };

  options.nixstart.system.user.gid = lib.mkOption {
    type = lib.types.int;
    default = 1000;
    description = ''
      The account's own group, matching its uid. NixOS puts a normal user in
      the shared `users` group (gid 100) by default; most other distributions
      give each user a group of their own with the same number. Taking the
      default here would leave every file in a migrated /home with a group
      that no longer means anything.
    '';
  };

  options.nixstart.system.user.initialPassword = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Password set on first boot, in the clear and world-readable in the Nix
      store. Only for a machine you are about to log into and change it on —
      `passwd` immediately after, and it is then ignored for ever after.

      Prefer a `user-password` secret in secrets/<hostname>.yaml, which is
      used in preference to this when present. Generate the hash with
      `mkpasswd -m yescrypt`.
    '';
  };

  config = {
    programs.zsh.enable = true;

    # An account nobody can log into is worse than a weak first password, and
    # far harder to notice — it looks fine until the first boot.
    assertions = [
      {
        assertion = hasSopsPassword || cfg.user.initialPassword != null;
        message = ''
          No password for ${cfg.user.name} on ${config.networking.hostName}.
          Either add a `user-password` secret to secrets/${config.networking.hostName}.yaml
          (a hash from `mkpasswd -m yescrypt`), or set
          nixstart.system.user.initialPassword and change it after first boot.
        '';
      }
    ];

    users.groups.${cfg.user.name}.gid = cfg.user.gid;

    users.users.${cfg.user.name} = {
      isNormalUser = true;
      uid = cfg.user.uid;
      group = cfg.user.name;
      description = cfg.user.fullName;
      shell = pkgs.zsh;
      hashedPasswordFile = lib.mkIf hasSopsPassword sops.user-password.path;
      initialPassword = lib.mkIf (!hasSopsPassword) cfg.user.initialPassword;
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
        "input"
      ]
      ++ cfg.user.extraGroups;
    };

    # stage-03 finished with `chown -R $(id -un) $HOME` to undo the damage from
    # the stages that ran as root. Nothing here writes into a home directory as
    # root, so there is nothing to repair.
    security.sudo.wheelNeedsPassword = true;
  };
}
