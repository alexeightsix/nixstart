# Battery warnings.
#
# The tracked i3status.toml has a bare `[[block]] block = "battery"` with no
# thresholds, so the bar shows a percentage and nothing else happens as it
# falls — the first real signal is the machine suspending. On a laptop with a
# 60W charger that is easy to walk away from, that is the wrong first signal.
#
# Two layers, because they fail differently:
#
#   the bar      always visible, colour-coded, no interaction needed
#   batsignal    a dunst popup at each low threshold, urgency rising to
#                critical. Only the way down is worth a popup; the "full"
#                notification is off (-f 0) because it repeats for as long as
#                the battery sits topped out on the charger.
#
# The popup is what dunstrc's [urgency_critical] section was already styled
# for — red, and `timeout = 0` so it does not disappear on its own. Nothing
# was sending critical notifications until now.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  config = lib.mkIf cfg.desktop.enable {
    systemd.user.services.batsignal = {
      Unit = {
        Description = "Battery threshold notifications";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];

        # The battery check, at runtime rather than as a host option saying
        # "this is a laptop". systemd skips a unit whose Condition is unmet
        # rather than failing it, so a machine with no battery simply never
        # starts batsignal — and the glob catches BAT1 as well as BAT0, which
        # a hardcoded path would not.
        ConditionPathExistsGlob = "/sys/class/power_supply/BAT*";
      };
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        # -w warning, -c critical, -d danger (runs -D), -f full.
        # -D is deliberately a notification and not a suspend: upower already
        # owns the action at 5% (system/hardware/xps13.nix), and two things
        # racing to suspend the machine is worse than either alone.
        ExecStart = lib.concatStringsSep " " [
          (lib.getExe pkgs.batsignal)
          "-w 25"
          "-c 15"
          "-d 5"
          # -f 0 disables the "battery is full" popup. At 100% on the charger it
          # re-fires on every poll, and a full battery is not something worth
          # interrupting for — only the way down is. Leaving it off also lets
          # batsignal back off its polling while discharging.
          "-f 0"
          "-m 60" # poll once a minute; the default 60s is fine and cheap
          "-a i3" # appname shown in the notification
          "-e" # let the non-critical popups time out instead of sticking
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    home.packages = with pkgs; [
      batsignal
      acpi # `acpi -V` when you want the numbers rather than the bar
    ];
  };
}
