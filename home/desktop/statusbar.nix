# i3status-rust.
#
# scripts/i3status-select.sh chose between i3status.toml and
# i3status-desktop.toml at runtime by testing for /sys/class/power_supply/BAT0,
# and exec'd /usr/bin/i3status-rs — a path that does not exist here. The two
# files differed by one block (battery), so there is one config now and the
# battery block detects its own absence.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

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

  # One list, unconditionally. The battery block used to be gated on a host
  # option saying "this is a laptop", which was a build-time guess at a
  # runtime fact. i3status-rust already answers the question itself: with no
  # battery device present it renders `missing_format`, and that is empty
  # here, so the block occupies nothing on a machine that has no battery.
  blocks = [
    {
      block = "cpu";
      info_cpu = 20;
      warning_cpu = 50;
      critical_cpu = 90;
    }
    { block = "temperature"; }
    {
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
      # The self-detection. No BAT0 means no output rather than an error line
      # in the bar, which is what makes the host option unnecessary.
      missing_format = "";
    }
    {
      block = "net";
      # The bar is `mode hide`, so this is a pull rather than a push: hold $mod
      # to see which network you are on, the same way you already read battery
      # and time. That is also why there is no tray applet — i3bar's tray is
      # XEmbed only and nixpkgs builds nm-applet with -Dappindicator=yes, so it
      # would have needed a snixembed shim to render in a bar that is hidden
      # by default anyway.
      #
      # `missing_format` renders text rather than nothing. The battery block
      # above hides itself because a missing battery is a permanent hardware
      # fact; "no network" is a transient state, and the whole point of the
      # block is to show it.
      #
      # No `$icon` in `missing_format`: the block leaves the icon unset when
      # there is no device, and the line then fails as "Failed to render full
      # text" rather than falling back. Literal text is the only safe form.
      format = " $icon {$ssid $signal_strength|Wired} ";
      missing_format = " offline ";
      click = [
        {
          button = "left";
          cmd = "${lib.getExe config.programs.ghostty.package} -e ${lib.getExe' pkgs.networkmanager "nmtui"}";
        }
      ];
    }
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
