# The i3 configuration.
#
# i3config was the one file that never got the path treatment the rest of the
# repository did: link.sh derives $DOTFILES from its own location and common.sh
# derives $KICKSTART from BASH_SOURCE, but i3config still says
# `$HOME/kickstart/dotfiles/picom.conf` and `$HOME/kickstart/scripts/xrandr.sh`
# in six places. Those are interpolated now, so the clone can live anywhere.
#
# Written with `xdg.configFile` and the existing text rather than
# `xsession.windowManager.i3`'s option tree: the config is 230 lines of
# bindcode tables and Rose Pine colours that translate to Nix attribute sets
# with no gain, and the option tree would obscure which keys are actually bound.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;
  desktop = cfg.desktop;

  # scripts/xrandr.sh was a single commented-out line, so every host ran an
  # empty script. The layout is per-host now, and a host with none runs nothing.
  monitorScript = pkgs.writeShellScript "monitors" ''
    ${desktop.monitors}
  '';

  statusCommand = "${lib.getExe pkgs.i3status-rust} ${
    config.xdg.configFile."i3status-rust/config.toml".source
  }";
in
{
  config = lib.mkIf desktop.enable {
    xdg.configFile."i3/config".text = ''
      set $mod Mod4

      workspace_layout default
      font pango:monospace 8

      new_window pixel 0
      gaps inner 0
      gaps outer 0
      floating_modifier $mod

      exec --no-startup-id ${lib.getExe pkgs.dex} --autostart --environment i3
      exec --no-startup-id ${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- ${lib.getExe pkgs.i3lock} --nofork
      exec --no-startup-id ${lib.getExe pkgs.picom} --config ${
        config.xdg.configFile."picom/picom.conf".source
      } -b
      exec --no-startup-id ${lib.getExe pkgs.feh} --bg-fill ${cfg.dotfiles}/../wallpapers/${desktop.wallpaper}
      exec --no-startup-id ${monitorScript}

      # vicinae is a systemd user unit now (modules/nixos/desktop/i3.nix), not
      # a `systemctl --user start` from the window manager.

      # jk: keyboard scroll mode (double-press Shift, then j/k).
      exec_always --no-startup-id sh -c "pkill -x jk; exec $HOME/.local/bin/jk"

      set $refresh_i3status killall -SIGUSR1 i3status
      bindsym XF86AudioRaiseVolume exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +10% && $refresh_i3status
      bindsym XF86AudioLowerVolume exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -10% && $refresh_i3status
      bindsym XF86AudioMute exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle && $refresh_i3status
      bindsym XF86AudioMicMute exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle && $refresh_i3status

      bindsym $mod+Return exec ${lib.getExe pkgs.ghostty}
      bindsym $mod+q kill
      bindsym $mod+Tab focus right

      # $mod+1..0 and $mod+Shift+1..0, over ten workspaces. Written as a fold
      # rather than twenty near-identical lines, which is the one place in
      # this file where the option tree's shape genuinely wins.
      ${lib.concatMapStringsSep "\n" (n: ''
        bindsym $mod+${toString (lib.mod n 10)} workspace number ${toString n}
        bindsym $mod+Shift+${toString (lib.mod n 10)} move container to workspace number ${toString n}
      '') (lib.range 1 10)}

      # The numpad, with and without NumLock. bindcode rather than bindsym
      # because the keysym a numpad key produces depends on the lock state,
      # so bindsym would only ever catch one of the two.
      ${lib.concatStringsSep "\n" (
        lib.imap1
          (i: code: ''
            bindcode $mod+Shift+Mod2+${toString code} move container to workspace number ${toString i}
            bindcode $mod+Shift+${toString code} move container to workspace number ${toString i}
          '')
          [
            87
            88
            89
            83
            84
            85
            79
            80
            81
            90
          ]
      )}

      mode "resize" {
          bindsym Left resize shrink width 10 px or 10 ppt
          bindsym Down resize grow height 10 px or 10 ppt
          bindsym Up resize shrink height 10 px or 10 ppt
          bindsym Right resize grow width 10 px or 10 ppt
          bindsym Return mode "default"
          bindsym Escape mode "default"
      }

      bindsym $mod+r mode "resize"
      bindsym $mod+Shift+c reload
      bindsym $mod+Shift+r restart

      bindsym $mod+b focus up
      bindsym $mod+j focus left
      bindsym $mod+k focus down
      bindsym $mod+o focus right
      bindsym $mod+Down focus down
      bindsym $mod+Left focus left
      bindsym $mod+Right focus right
      bindsym $mod+Up focus up

      bindsym $mod+Shift+b move up
      bindsym $mod+Shift+j move left
      bindsym $mod+Shift+k move down
      bindsym $mod+Shift+o move right
      bindsym $mod+Shift+Left move left
      bindsym $mod+Shift+Down move down
      bindsym $mod+Shift+Up move up
      bindsym $mod+Shift+Right move right

      bindsym $mod+h split h
      bindsym $mod+v split v
      bindsym $mod+f fullscreen toggle
      bindsym $mod+s layout stacking
      bindsym $mod+g layout tabbed
      bindsym $mod+e layout toggle split
      bindsym $mod+Shift+space floating toggle
      bindsym $mod+space focus mode_toggle
      bindsym $mod+a focus parent

      assign [class="[zZ]oom.*"] 7
      assign [class="^[Tt]elegram.*"] 7
      assign [class="^[tT]eams.*"] 7
      assign [class="^[sS]lack.*"] 7
      assign [class="^[fF]irefox$"] 3

      for_window [class=(?i)firefox] focus
      for_window [class=TelegramDesktop] focus
      for_window [class="^.*"] border pixel 0

      ${builtins.readFile ./i3-colors.conf}

      bar {
          mode hide
          hidden_state hide
          modifier $mod
          padding 0 0 0 0
          bindsym button1 nop
          bindsym button4 nop
          bindsym button5 nop
          bindsym button6 nop
          bindsym button7 nop
          status_command ${statusCommand}
          position bottom
          tray_padding 0
          strip_workspace_numbers yes

          colors {
            active_workspace   $rp_rose $rp_overlay $rp_subtle $rp_iris
            background         $rp_base
            binding_mode       $rp_love $rp_love $rp_base
            focused_workspace  $rp_rose $rp_rose $rp_base
            inactive_workspace $rp_base $rp_base $rp_muted $rp_iris
            separator          $rp_iris
            statusline         $rp_text
            urgent_workspace   $rp_love $rp_love $rp_base $rp_iris
          }
      }

      bindsym $mod+Shift+s exec --no-startup-id "systemctl suspend"
      bindsym $mod+d exec --no-startup-id "${lib.getExe pkgs.vicinae} toggle"

      # flameshot: Ctrl+; -> interactive capture
      bindsym Control+semicolon exec --no-startup-id ${lib.getExe pkgs.flameshot} gui
      bindsym F10 exec --no-startup-id ${lib.getExe pkgs.flameshot} gui
    '';
  };
}
