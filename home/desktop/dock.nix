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

  # `xrandr --query` prints one line per output; the connected ones say
  # "connected" and never "disconnected", which is why the match is anchored
  # on the word with a space in front of it rather than a substring test.
  script = pkgs.writeShellApplication {
    name = "display-dock";
    runtimeInputs = [ pkgs.xrandr ];
    text = ''
      internal=${lib.escapeShellArg dock.internal}

      connected=$(xrandr --query | awk '/ connected/ { print $1 }')
      external=$(printf '%s\n' "$connected" | grep -vx "$internal" || true)

      if [ -z "$external" ]; then
        # Undocked. The panel is the only thing left, so it had better be on —
        # this is the branch that recovers from unplugging the last monitor
        # while the panel was off, which otherwise leaves a machine with no
        # enabled output at all and no way to fix it from the GUI.
        xrandr --output "$internal" --auto --primary
        exit 0
      fi

      # Docked. The first external output is primary; any further ones extend
      # to its right, in the order xrandr lists them.
      last=""
      args=()
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
