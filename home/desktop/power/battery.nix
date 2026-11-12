# Battery warnings. Two layers, because they fail differently:
#
#   the bar      always visible, colour-coded, no interaction needed
#   batsignal    a dunst popup at each low threshold, urgency rising to
#                critical. Only the way down is worth a popup; the "full"
#                notification is off (-f 0) because it repeats for as long as
#                the battery sits topped out on the charger.
#
# dunstrc's [urgency_critical] styles the popup red with `timeout = 0`.
{
  lib,
  pkgs,
  ...
}:
{
  systemd.user.services.batsignal = {
    Unit = {
      Description = "Battery threshold notifications";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];

      # Skipped, not failed, if there is no battery; the glob catches BAT1 too.
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
}
