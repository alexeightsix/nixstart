# Idle hibernate.
#
# The session already locks on idle (xss-lock, from i3); this hibernates once
# it has stayed idle for `hibernateAfter` minutes.
#
# Not logind's IdleAction: logind has no idle notion for an X11 session with
# i3 (IdleHint stays "no"). xautolock reads X's own idle counter, so media
# playback and anything else that inhibits the screensaver inhibits this too.
#
# Hibernate matches upower's criticalPowerAction; see
# system/hardware/xps13.nix, including the note on unencrypted swap.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  minutes = cfg.desktop.hibernateAfter;
in
{
  config = lib.mkIf (minutes != null) {
    systemd.user.services.idle-hibernate = {
      Unit = {
        Description = "Hibernate after ${toString minutes} minutes of X idle time";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];

        # Same runtime battery check as batsignal.
        ConditionPathExistsGlob = "/sys/class/power_supply/BAT*";
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = lib.concatStringsSep " " [
          "${pkgs.xautolock}/bin/xautolock"
          "-time ${toString minutes}"

          # xautolock will not start a second locker while the first is still
          # running, and `systemctl hibernate` blocks until the machine has
          # come back up — so this is one hibernate per idle period, not a
          # loop. The lock screen is xss-lock's job: it takes the sleep
          # inhibitor on the way down, which is the ordering that guarantees
          # the lock is up before the image is written.
          ''-locker "${pkgs.systemd}/bin/systemctl hibernate"''

          # Without this, the clock jump across a suspend or hibernate counts
          # as idle time, and the machine hibernates again moments after being
          # woken. -detectsleep restarts the count on resume instead.
          "-detectsleep"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
