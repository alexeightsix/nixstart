# i3status-rust.
{
  config,
  lib,
  pkgs,
  ...
}:
let

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
    {
      block = "battery";
      device = "BAT0";
      # The same thresholds batsignal notifies on, so the bar turning amber
      # and the popup arriving are one event.
      warning = 25.0;
      critical = 15.0;
      info = 60.0;
      good = 90.0;
      format = " $icon $percentage {$time_remaining.dur(hms:true, min_unit:m) |}";
      full_format = " $icon ";
      # No BAT0 means no output rather than an error line in the bar.
      missing_format = "";
    }
    {
      block = "net";
      # No tray applet: see home/desktop/network.nix. `missing_format`
      # renders text rather than nothing, since "no network" is exactly what
      # the block is for.
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
  home.packages = [ pkgs.i3status-rust ];

  xdg.configFile."i3status-rust/config.toml".source =
    (pkgs.formats.toml { }).generate "i3status-rust-config.toml"
      {
        icons_format = "{icon}";
        theme = rosePine;
        icons.icons = "awesome4";
        block = blocks;
      };
}
