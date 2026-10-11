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
  cfg = config.nixstart.home;
  desktop = cfg.desktop;

  # scripts/xrandr.sh was a single commented-out line, so every host ran an
  # empty script. The layout is per-host now, and a host with none runs nothing.
  monitorScript = pkgs.writeShellScript "monitors" ''
    ${desktop.monitors}
  '';

  statusCommand = "${lib.getExe pkgs.i3status-rust} ${
    config.xdg.configFile."i3status-rust/config.toml".source
  }";

  # Paired workspaces: $mod+N moves every screen at once.
  #
  # i3's own `workspace number N` focuses workspace N wherever it already is,
  # which on two screens means the keypress jumps focus to the other monitor
  # and leaves the one you were looking at untouched. What is wanted is one
  # workspace per screen, switched together — see desktop.pairedWorkspaces for
  # the naming, which is what makes both bars read the same number.
  #
  # A script rather than a chain of i3 commands because two things here can
  # only be known at the moment the key is pressed: how many screens are on,
  # and which one the keypress came from. i3's command language can express
  # neither, so a static `workspace 11; workspace 1` would always strand focus
  # on the primary and would switch a screen that is not plugged in.
  workspacePair = pkgs.writeShellApplication {
    name = "i3-workspace-pair";
    runtimeInputs = [
      pkgs.i3
      pkgs.jq
    ];
    text = ''
      action=''${1:-}
      target=''${2:-}

      # Active screens, the primary first and the rest left to right. The
      # pairing is positional rather than by connector name, so it follows the
      # dock onto a monitor this machine has never seen.
      mapfile -t screens < <(
        i3-msg -t get_outputs \
          | jq -r '[.[] | select(.active)] | sort_by([(.primary | not), .rect.x]) | .[].name'
      )

      # Where the keypress came from, so focus can be put back afterwards.
      focused=$(i3-msg -t get_workspaces \
        | jq -r 'first(.[] | select(.focused) | .output) // empty')

      # Screen 0 takes the bare number; every screen after it offsets by ten
      # and carries the original after a colon. i3 needs the names to differ;
      # the bar strips the "N:" prefix, so both screens still show the same
      # number.
      name_for() {
        if [ "$1" -eq 0 ]; then
          printf '%s' "$target"
        else
          printf '%d:%s' "$(( target + $1 * 10 ))" "$target"
        fi
      }

      position_of() {
        local i=0 name
        for name in "''${screens[@]}"; do
          if [ "$name" = "$1" ]; then
            printf '%s' "$i"
            return 0
          fi
          i=$(( i + 1 ))
        done
        printf '0'
      }

      join_commands() {
        local joined="" part
        for part in "$@"; do
          if [ -z "$joined" ]; then joined="$part"; else joined="$joined; $part"; fi
        done
        printf '%s' "$joined"
      }

      case "$action" in
        switch)
          parts=()
          for (( i = 0; i < ''${#screens[@]}; i++ )); do
            parts+=("workspace \"$(name_for "$i")\"")
          done
          # Switching walks the screens, so focus ends on the last one. Put it
          # back where it started — without this the keypress moves you to
          # another monitor, which is half of what made the old behaviour
          # annoying.
          if [ -n "$focused" ]; then
            parts+=("focus output \"$focused\"")
          fi
          i3-msg "$(join_commands "''${parts[@]}")" > /dev/null
          ;;
        move)
          # The half of the pair belonging to the screen you are on, so a
          # window does not fly to the monitor from the laptop panel.
          i3-msg "move container to workspace \"$(name_for "$(position_of "$focused")")\"" > /dev/null
          ;;
        *)
          echo "usage: i3-workspace-pair switch|move <1-10>" >&2
          exit 2
          ;;
      esac
    '';
  };

  # Which screen Ctrl+; captures.
  #
  # `flameshot screen` without -n does not quietly fall back to the monitor
  # holding the cursor the way `--help` claims. On two screens it puts up its
  # own chooser — "Monitor 1: DP-1 / Click to select" beside "Monitor 2:
  # eDP-1" — and that chooser is an ordinary window, so i3 tiles it into half
  # a workspace instead of showing it over the desktop. A keypress meant to
  # start a screenshot ended up asking a question and corrupting the layout to
  # ask it.
  #
  # -n answers the question up front. Qt numbers screens primary-first and
  # then in RandR order, which is the order `xrandr --listmonitors` prints and
  # the order workspacePair above already sorts into; verified with
  # `flameshot screen -n N -r`, which returns 1920x1080 for 0 and 1680x1050
  # for 1 here. With -n the capture widget comes up at exactly the output's
  # geometry and i3 leaves it alone.
  #
  # The pointer is warped onto that screen as well, because -n decides which
  # monitor is captured but not where the cursor is: without the warp the
  # selector opens on the focused screen with the mouse still on the other
  # one. Skipped when the pointer is already inside the output, so mouse and
  # focus together moves nothing.
  screenshotFocused = pkgs.writeShellApplication {
    name = "flameshot-focused-screen";
    runtimeInputs = [
      pkgs.flameshot
      pkgs.i3
      pkgs.jq
      pkgs.xdotool
    ];
    text = ''
      focused=$(i3-msg -t get_workspaces \
        | jq -r 'first(.[] | select(.focused) | .output) // empty')

      # Position of that output in Qt's screen order, and its geometry in root
      # coordinates. Both come out of one query so they cannot disagree.
      index=""; ox=""; oy=""; ow=""; oh=""
      if [ -n "$focused" ]; then
        read -r index ox oy ow oh < <(
          i3-msg -t get_outputs \
            | jq -r --arg o "$focused" '
                [.[] | select(.active)]
                  | sort_by([(.primary | not), .rect.x, .rect.y])
                  | (map(.name) | index($o)) as $i
                  | if $i == null then empty
                    else .[$i].rect | "\($i) \(.x) \(.y) \(.width) \(.height)"
                    end
              '
        )
      fi

      # Primary when focus does not resolve to an active output. Anything is
      # better than omitting -n, which is what puts the chooser back.
      index=''${index:-0}

      # `getmouselocation --shell` is X=/Y=/SCREEN=/WINDOW= lines. Read rather
      # than eval'd: the point is two integers, not four shell assignments.
      px=""; py=""
      while IFS='=' read -r key value; do
        case "$key" in
          X) px=$value ;;
          Y) py=$value ;;
        esac
      done < <(xdotool getmouselocation --shell)

      if [ -n "$ow" ] && [ -n "$oh" ] && [ -n "$px" ] && [ -n "$py" ]; then
        if [ "$px" -lt "$ox" ] \
          || [ "$px" -ge "$(( ox + ow ))" ] \
          || [ "$py" -lt "$oy" ] \
          || [ "$py" -ge "$(( oy + oh ))" ]; then
          xdotool mousemove "$(( ox + ow / 2 ))" "$(( oy + oh / 2 ))"
        fi
      fi

      exec flameshot screen -n "$index" -e
    '';
  };

  # `workspace <name> output primary|nonprimary` — i3 resolves both of those
  # against the X primary flag rather than against a connector (randr.c's
  # get_output_by_name), which is the same trick barOutputs uses below and the
  # reason none of this names DP-1.
  #
  # Only two screens are pinned: `nonprimary` matches the first non-primary
  # output and there is no name for a third. The script still switches a third
  # screen; its workspaces simply land wherever i3 would have put them.
  workspaceName =
    screen: n: if screen == 0 then toString n else "${toString (n + screen * 10)}:${toString n}";

  workspaceAssignments = lib.optionalString desktop.pairedWorkspaces (
    lib.concatMapStringsSep "\n" (
      n:
      ''workspace "${workspaceName 0 n}" output primary''
      + "\n"
      + ''workspace "${workspaceName 1 n}" output nonprimary''
    ) (lib.range 1 10)
  );

  # The two halves of a workspace keybinding, paired or not.
  wsSwitch =
    n:
    if desktop.pairedWorkspaces then
      "exec --no-startup-id ${lib.getExe workspacePair} switch ${toString n}"
    else
      "workspace number ${toString n}";

  wsMove =
    n:
    if desktop.pairedWorkspaces then
      "exec --no-startup-id ${lib.getExe workspacePair} move ${toString n}"
    else
      "move container to workspace number ${toString n}";

  # The `bar { output ... }` lines, or nothing at all — which is i3's own
  # default of a bar on every screen. See desktop.barOutputs for what the
  # names mean; "primary" is the one that follows the dock.
  #
  # Each line carries the four spaces the generated file wants. The indented
  # string below strips the common prefix from its own literal lines, but an
  # interpolation's content lands verbatim and has to indent itself.
  barOutputs = lib.concatMapStrings (o: "output ${o}\n    ") desktop.barOutputs;
in
{
  config = lib.mkIf desktop.enable {
    xdg.configFile."i3/config".text = ''
      set $mod Mod4

      workspace_layout default
      font pango:monospace 8

      # Leave the pointer where it is. i3's default is `mouse_warping output`,
      # which teleports the cursor to the middle of a screen whenever focus
      # moves to it — including the focus moves the workspace switch below
      # makes on its way through the screens, so every $mod+N threw the
      # pointer across the desk.
      mouse_warping none

      new_window pixel 0
      gaps inner 0
      gaps outer 0
      floating_modifier $mod

      exec --no-startup-id ${lib.getExe pkgs.dex} --autostart --environment i3
      exec --no-startup-id ${pkgs.xss-lock}/bin/xss-lock --transfer-sleep-lock -- ${lib.getExe pkgs.i3lock} --nofork
      exec --no-startup-id ${lib.getExe pkgs.picom} --config ${
        config.xdg.configFile."picom/picom.conf".source
      } -b
      exec --no-startup-id ${lib.getExe pkgs.feh} --bg-fill ${desktop._resolvedWallpaper}
      exec --no-startup-id ${monitorScript}

      # vicinae is a systemd user unit now (modules/nixos/desktop/i3.nix), not
      # a `systemctl --user start` from the window manager.

      set $refresh_i3status killall -SIGUSR1 i3status
      bindsym XF86AudioRaiseVolume exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ +10% && $refresh_i3status
      bindsym XF86AudioLowerVolume exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-volume @DEFAULT_SINK@ -10% && $refresh_i3status
      bindsym XF86AudioMute exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-sink-mute @DEFAULT_SINK@ toggle && $refresh_i3status
      bindsym XF86AudioMicMute exec --no-startup-id ${pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle && $refresh_i3status

      bindsym $mod+Return exec ${lib.getExe config.programs.ghostty.package}
      bindsym $mod+q kill
      bindsym $mod+Tab focus right

      # $mod+1..0 and $mod+Shift+1..0, over ten workspaces. Written as a fold
      # rather than twenty near-identical lines, which is the one place in
      # this file where the option tree's shape genuinely wins.
      #
      # What each binding expands to depends on desktop.pairedWorkspaces: i3's
      # own `workspace number N`, or the script that moves every screen.
      ${lib.concatMapStringsSep "\n" (n: ''
        bindsym $mod+${toString (lib.mod n 10)} ${wsSwitch n}
        bindsym $mod+Shift+${toString (lib.mod n 10)} ${wsMove n}
      '') (lib.range 1 10)}

      # Which screen each workspace belongs to. Empty unless the workspaces
      # are paired.
      ${workspaceAssignments}

      # The numpad, with and without NumLock. bindcode rather than bindsym
      # because the keysym a numpad key produces depends on the lock state,
      # so bindsym would only ever catch one of the two.
      ${lib.concatStringsSep "\n" (
        lib.imap1
          (i: code: ''
            bindcode $mod+Shift+Mod2+${toString code} ${wsMove i}
            bindcode $mod+Shift+${toString code} ${wsMove i}
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
      # flameshot's monitor chooser is a plain window and i3 tiles it into the
      # layout. screenshotFocused passes -n so it should never appear; this is
      # the net under that, not the fix.
      for_window [class="(?i)flameshot"] floating enable

      ${builtins.readFile ./i3-colors.conf}

      bar {
          # `dock`, not `hide`. The bar used to exist only while $mod was
          # held — `mode hide` with `hidden_state hide` — which on a screen
          # you are not holding a key on is indistinguishable from no bar at
          # all. Dock keeps it on screen and reserves the 21px it occupies,
          # so nothing is laid out underneath it.
          #
          # `modifier` and `hidden_state` are gone with it: both only mean
          # anything to a bar that hides, and i3 ignores them here.
          ${barOutputs}mode dock
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

      # Wifi. nmtui rather than a tray applet: i3bar's tray is XEmbed only and
      # nixpkgs builds nm-applet with -Dappindicator=yes, so an applet would
      # need a snixembed shim to render in the bar at all. That argument used
      # to carry "in a bar that is hidden by default anyway" as a second half;
      # the bar docks now, so the XEmbed half is the whole of it.
      # The net block in statusbar.nix is the at-a-glance half of this; $mod+w
      # is the half that can actually change networks. $mod+d stays the
      # launcher.
      bindsym $mod+w exec --no-startup-id ${lib.getExe config.programs.ghostty.package} -e ${lib.getExe' pkgs.networkmanager "nmtui"}

      # flameshot. Two keys, two scopes, and the difference only started
      # mattering once the built-in panel was switched on: `gui` overlays the
      # whole X root window, which is now 1920x2130 spanning both stacked
      # screens, including the two 120x1050 bands beside the narrower panel
      # that no monitor displays. That is a capture canvas, not a screen.
      #
      # `screen -e` confines the same interactive selector to a single
      # monitor, and screenshotFocused above picks which one from i3's focused
      # output instead of from wherever the mouse was left. Ctrl+; is the
      # common case and gets that; F10 keeps the everything-at-once grab for a
      # capture that really does span both.
      bindsym Control+semicolon exec --no-startup-id ${lib.getExe screenshotFocused}
      bindsym F10 exec --no-startup-id ${lib.getExe pkgs.flameshot} gui
    '';
  };
}
