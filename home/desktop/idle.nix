# Idle hibernate.
#
# The session already locks on idle: i3 execs `xss-lock --transfer-sleep-lock`
# (home/desktop/i3.nix), which fires off X's own screensaver timer — the
# server default, 600s — and holds a sleep inhibitor so the lock screen is up
# before the machine goes down. What nothing did was eventually *stop* the
# machine, so a laptop left on the desk sat locked and awake until the battery
# reached upower's 5% action.
#
# This is the second half of that chain: still idle 30 minutes in, hibernate.
#
# Why a second daemon rather than logind's IdleAction, which is the obvious
# answer and the one that does not work here: logind has no idle notion for an
# X11 session. It derives IdleHint from TTY atime for text sessions, and for
# graphical ones relies on the compositor setting the hint over D-Bus — which
# i3 does not do, and neither does xss-lock. `loginctl show-session` on this
# machine reports Type=x11 and IdleHint=no indefinitely, so IdleActionSec
# would simply never elapse.
#
# So the timer has to come from X, where the idle counter actually lives.
# xautolock reads the X server's idle time, which means it inherits the same
# inhibition every other X client already honours: anything calling
# XResetScreenSaver or holding the screensaver API open — mpv, Firefox and
# Chrome during playback, screen shares — keeps the counter at zero and the
# hibernate with it.
#
# Hibernate rather than suspend is deliberate and the host is already set up
# for it: swap is a 36.3G partition against 30GiB of RAM, and the scripted
# initrd resumes by scanning swapDevices for a swsuspend signature, so no
# `resume=` kernel parameter is needed. upower's criticalPowerAction is
# "Hibernate" too (system/hardware/xps13.nix) — this makes the idle path agree
# with the battery one.
#
# Worth knowing: that swap partition is not encrypted, while root is LUKS. A
# hibernate image is a verbatim copy of RAM, so this writes memory contents to
# plaintext disk. See the note in system/hardware/xps13.nix.
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
  config = lib.mkIf (cfg.desktop.enable && minutes != null) {
    systemd.user.services.idle-hibernate = {
      Unit = {
        Description = "Hibernate after ${toString minutes} minutes of X idle time";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];

        # Same runtime check as batsignal: a machine with no battery is a
        # desktop, and hibernating a desktop on idle is not wanted. systemd
        # skips a unit whose Condition is unmet rather than failing it.
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
