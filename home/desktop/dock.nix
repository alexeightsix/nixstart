# Follow the external monitor.
#
# The laptop had `autorandr = true` and no saved profiles, which is a
# configuration that cannot do anything: `autorandr --change` matches the
# connected outputs against profiles in ~/.config/autorandr, finds none, and
# exits 0. The service log shows exactly that — started, finished, 70ms, no
# xrandr call. Docking the machine changed nothing and there was no error to
# notice.
#
# There is a second, quieter half to it. home-manager's services.autorandr
# only installs a user unit wanted by graphical-session.target, so even with
# profiles saved it would run at login and never again; the udev rule that
# makes autorandr react to a monitor being plugged in ships inside the
# autorandr package (etc/udev/rules.d/40-monitor-hotplug.rules) and nothing
# was installing it. Hotplug was not wired up at all.
#
# So this module does not try to fix autorandr. It answers the actual
# requirement — "use the monitor, turn the laptop panel off" — with a rule
# about kinds of output rather than about specific monitors, so it applies to
# a display this machine has never seen. autorandr stays enabled and still
# runs first at login, so a hand-saved profile for a familiar dock continues
# to win.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  desktop = cfg.desktop;
  dock = desktop.dock;

  # `xrandr --query` prints a header line per output with the connector name
  # first and the word connected/disconnected second, then one indented line
  # per available mode. Both facts are needed below, so the parsing is on the
  # second field rather than a substring match — "disconnected" contains
  # "connected", and telling them apart by anchoring on a leading space is a
  # trick that works right up until it does not.
  script = pkgs.writeShellApplication {
    name = "display-dock";
    runtimeInputs = [
      pkgs.xrandr
      pkgs.gawk
      pkgs.gnugrep
    ];
    text = ''
      internal=${lib.escapeShellArg dock.internal}

      all=$(xrandr --query | awk '$2 ~ /^(dis)?connected$/ { print $1 }')

      # Connected *and* carrying at least one mode. A DisplayPort connector
      # reports itself connected as soon as the link is up, which can be a
      # moment before the sink has handed over an EDID; in that window the
      # output has no modes, --auto cannot bring it up, and treating it as a
      # working monitor would switch the panel off in favour of a display
      # that shows nothing. Waiting for modes costs nothing — another drm
      # event arrives when the EDID lands, and the watcher below re-runs.
      usable=$(xrandr --query | awk '
        /^[^ ]/            { out = ($2 == "connected") ? $1 : ""; next }
        out != ""          { print out; out = "" }
      ')

      external=$(printf '%s\n' "$usable" | grep -vx "$internal" || true)

      args=()

      # Hand back the CRTC of anything that is no longer usable, before
      # deciding on the rest.
      #
      # An unplugged monitor keeps the mode and position it had until
      # something explicitly takes them away: xrandr goes on listing it as
      # "DP-1 disconnected 1920x1080+0+0" with its old modeline attached. i3
      # then sees two outputs sharing the origin, treats them as clones, and
      # clamps the panel to the stale geometry — a 1920x1200 screen laid out
      # as 1920x1080, with the bottom 120px of every window and the bar
      # falling off the end of it. Turning the panel back on is not enough to
      # clear that, which is what the undocked branch below used to do and
      # all it used to do.
      #
      # The panel is skipped here because both branches below give it an
      # explicit state of its own, and naming one output twice in a single
      # xrandr invocation is ambiguous.
      for output in $all; do
        if [ "$output" = "$internal" ]; then
          continue
        fi
        if ! printf '%s\n' "$usable" | grep -qx "$output"; then
          args+=(--output "$output" --off)
        fi
      done

      if [ -z "$external" ]; then
        # Undocked. The panel is the only thing left, so it had better be on —
        # this is the branch that recovers from unplugging the last monitor
        # while the panel was off, which otherwise leaves a machine with no
        # enabled output at all and no way to fix it from the GUI.
        args+=(--output "$internal" --auto --primary)
        xrandr "''${args[@]}"
        exit 0
      fi

      # Docked. The first external output is primary; any further ones extend
      # to its right, in the order xrandr lists them.
      last=""
      for output in $external; do
        if [ -z "$last" ]; then
          args+=(--output "$output" --auto --primary)
        else
          args+=(--output "$output" --auto --right-of "$last")
        fi
        last="$output"
      done

      # The panel: off, or kept on at the end of the chain it sits next to.
      # right-of anchors to the last external, left-of to the first, so that
      # it lands outside the row rather than in the middle of it.
      ${
        lib.optionalString (!dock.keepInternal) ''
          args+=(--output "$internal" --off)
        ''
      }${
        lib.optionalString (dock.keepInternal && dock.internalPosition == "right-of") ''
          args+=(--output "$internal" --auto --right-of "$last")
        ''
      }${
        lib.optionalString (dock.keepInternal && dock.internalPosition == "left-of") ''
          args+=(--output "$internal" --auto --left-of "$(printf '%s\n' "$external" | head -n1)")
        ''
      }

      xrandr "''${args[@]}"
    '';
  };
in
{
  config = lib.mkIf (desktop.enable && dock.enable) {
    home.packages = [ script ];

    # Applied once when the session comes up. After autorandr, so that a saved
    # profile is the starting point and this only has to correct it.
    systemd.user.services.display-dock = {
      Unit = {
        Description = "Use the external monitor and switch the built-in panel off";
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "autorandr.service"
        ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe script;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # And on every hotplug.
    #
    # The obvious way to do this is the udev rule in the autorandr package,
    # but it runs `systemctl start autorandr.service` against the *system*
    # manager, and the unit that matters here is a user one belonging to a
    # session started by startx — udev cannot see which user that is, and
    # reaching into the user manager from a udev rule means guessing at
    # XAUTHORITY and DISPLAY.
    #
    # Watching the same events from inside the session avoids all of that. The
    # service is part of the graphical session, so it already has the right
    # DISPLAY and dies with it; `udevadm monitor` needs no privileges to read
    # kernel uevents. One line of output per drm change, one run of the script.
    systemd.user.services.display-dock-watch = {
      Unit = {
        Description = "Re-apply the display layout when a monitor is plugged or unplugged";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # `udevadm monitor` never exits, so this is the long-running half.
        # --udev rather than --kernel: the udev-processed event arrives after
        # the kernel has updated the connector state, so xrandr sees the new
        # topology. A drm change is also emitted on DPMS and mode sets, so the
        # script runs more often than strictly necessary; it is idempotent and
        # takes milliseconds, which is cheaper than trying to filter.
        ExecStart = pkgs.writeShellScript "display-dock-watch" ''
          ${pkgs.systemd}/bin/udevadm monitor --udev --subsystem-match=drm \
            | while read -r _; do
                ${lib.getExe script} || true
              done
        '';
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
