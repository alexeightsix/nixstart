# The account, its password, and the groups the enabled modules need it in.
#
# With no password set the account cannot log in at all (lightdm rejects an
# empty password, and sudo needs one), so one of the two password sources
# below has to be set or the build fails.
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
      store. Run `passwd` on first login; it is ignored from then on.

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

    security.sudo.wheelNeedsPassword = true;

    # Except for the rebuild itself.
    #
    # A coding agent has no terminal to type a sudo password into, so without
    # this it cannot apply what it edits. This is effectively root (the flake
    # is user-writable); acceptable on a single-user laptop with an encrypted
    # disk, not elsewhere. Named by /run/current-system/sw/bin because a store
    # path would stop matching at the next generation.
    security.sudo.extraRules = [
      {
        users = [ cfg.user.name ];
        commands = [
          {
            command = "/run/current-system/sw/bin/nixos-rebuild";
            options = [ "NOPASSWD" ];
          }
          # scripts/apply/apply.sh starts this first when a failed activation has
          # left the daemon down, and a password prompt there would block
          # the rebuild before it began. Spelled out with its argument, so
          # it permits this one unit and not `systemctl start` in general.
          {
            command = "/run/current-system/sw/bin/systemctl start nix-daemon.socket";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };
}
