# The i3 session's system-level parts. The configuration file itself is
# home-manager's (modules/home/desktop/i3.nix) — this is the daemons and
# helpers it execs, which stage-01's package list was missing.
#
# i3config execs dex-autostart, xss-lock and i3lock; none of the three was
# installed by any stage. On Fedora they came in as dependencies of something
# else, which is why it worked. Naming them is the fix.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.system.desktop;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      dex
      i3lock
      xss-lock
      picom
      dunst
      flameshot
      i3status-rust
      vicinae
      pavucontrol
      playerctl
      brightnessctl
    ];

    # stage-14 did `ln -s /usr/bin/pavucontrol /usr/bin/sound` so the launcher
    # could find it by that name. A wrapper in the system profile does the same
    # thing without writing into a directory the package manager owns.
    environment.shellAliases.sound = lib.getExe pkgs.pavucontrol;

    # vicinae runs as a per-user daemon. stage-02 enabled it with a `runuser`
    # incantation that had to reconstruct XDG_RUNTIME_DIR by hand.
    systemd.user.services.vicinae = {
      description = "Vicinae launcher daemon";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];

      # Desktop entries name their binaries bare — `Exec=ghostty`, `Exec=btop`,
      # `Exec=nvim`, `Exec=pavucontrol` — and vicinae execs them directly rather
      # than through a shell, so they have to be found on this unit's PATH.
      # NixOS gives a user unit coreutils, findutils, grep, sed and systemd and
      # nothing else, so every one of those lookups failed with
      #
      #   Failed to start app: "Child process set up failed: execve: No such file or directory"
      #
      # and the launcher could start only the few entries whose Exec is already
      # an absolute store path (Chrome, flameshot). These two profiles are where
      # a user's applications actually live.
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
  };
}
