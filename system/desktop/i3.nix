# The i3 session's system-level parts: the daemons and helpers the i3 config
# execs. The configuration file itself is home-manager's (home/desktop/wm/i3.nix).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    dex
    xss-lock
    picom
    playerctl
  ];

  # `sound` opens pavucontrol.
  environment.shellAliases.sound = lib.getExe pkgs.pavucontrol;

  # vicinae runs as a per-user daemon.
  systemd.user.services.vicinae = {
    description = "Vicinae launcher daemon";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    # Desktop entries name their binaries bare — `Exec=ghostty`, `Exec=btop`,
    # `Exec=nvim`, `Exec=pavucontrol` — and vicinae execs them directly rather
    # than through a shell, so they have to be found on this unit's PATH.
    # NixOS gives a user unit only coreutils, findutils, grep, sed and
    # systemd; these two profiles are where a user's applications live.
    path = [
      "/run/current-system/sw"
      "/etc/profiles/per-user/${config.nixstart.system.user.name}"
    ];
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.vicinae} server";
      Restart = "on-failure";
    };
  };

  services.gnome.gnome-keyring.enable = true;
}
