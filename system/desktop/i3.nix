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
  cfg = config.kickstart.system.desktop;
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
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.vicinae} server";
        Restart = "on-failure";
      };
    };

    services.gnome.gnome-keyring.enable = true;
  };
}
