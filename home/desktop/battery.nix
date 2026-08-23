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
#   batsignal    a dunst popup at each threshold, urgency rising to critical
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
  isLaptop = cfg.desktop.statusBar == "laptop";
in
{
  config = lib.mkIf (cfg.desktop.enable && isLaptop) {
    systemd.user.services.batsignal = {
      Unit = {
        Description = "Battery threshold notifications";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
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
          "-f 100"
          "-m 60" # poll once a minute; the default 60s is fine and cheap
          "-a i3" # appname shown in the notification
          "-e" # notify when the charger goes in or out
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
