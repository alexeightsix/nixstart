# i3status-rust.
#
# scripts/i3status-select.sh chose between i3status.toml and
# i3status-desktop.toml at runtime by testing for /sys/class/power_supply/BAT0,
# and exec'd /usr/bin/i3status-rs — a path that does not exist here. The two
# files differ by one block (battery), so the shared part is expressed once and
# the host says which variant it is.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;

  rosePine = {
    theme = "plain";
    overrides = {
      idle_bg = "#191724";
      idle_fg = "#e0def4";
      info_bg = "#9ccfd8";
      info_fg = "#191724";
      good_bg = "#31748f";
      good_fg = "#e0def4";
      warning_bg = "#f6c177";
      warning_fg = "#191724";
      critical_bg = "#eb6f92";
      critical_fg = "#191724";
      separator = "";
      separator_bg = "auto";
      separator_fg = "auto";
    };
  };

  blocks = [
    {
      block = "cpu";
      info_cpu = 20;
      warning_cpu = 50;
      critical_cpu = 90;
    }
    { block = "temperature"; }
  ]
  ++ lib.optional (cfg.desktop.statusBar == "laptop") {
    block = "battery";
    device = "BAT0";
    # The tracked file had no thresholds at all, so the block never left the
    # idle colour and the Rose Pine warning/critical entries below it were
    # unreachable. These are the same numbers batsignal notifies on, so the
    # bar turning amber and the popup arriving are one event, not two.
    warning = 25.0;
    critical = 15.0;
    info = 60.0;
    good = 90.0;
    format = " $icon $percentage {$time_remaining.dur(hms:true, min_unit:m) |}";
    full_format = " $icon ";
    # A missing battery is normal on the desktop variant and should not be an
    # error line in the bar.
    missing_format = "";
  }
  ++ [
    {
      block = "memory";
      format = " $icon $mem_total_used_percents.eng(w:2) ";
      format_alt = " $icon_swap $swap_used_percents.eng(w:2) ";
    }
    {
      block = "time";
      interval = 5;
      format = " $timestamp.datetime(f:'%a %d/%m %R') ";
    }
  ];
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ pkgs.i3status-rust ];

    xdg.configFile."i3status-rust/config.toml".source =
      (pkgs.formats.toml { }).generate "i3status-rust-config.toml"
        {
          icons_format = "{icon}";
          theme = rosePine;
          icons.icons = "awesome4";
          block = blocks;
        };
  };
}
