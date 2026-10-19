# Agent mode: keep the terminal on the laptop panel.
#
# The machine runs coding agents in Ghostty (home/dev/agents.nix) while the
# work being supervised happens on the external monitor. The useful layout is
# therefore asymmetric — the agent's terminal belongs on the panel underneath,
# permanently visible, and everything else belongs on the monitor — and that
# is exactly what paired workspaces take away: $mod+N switches both screens at
# once, so the panel's half of the pair changes with the monitor's and the
# terminal goes out of sight with it.
#
# Pinning the terminal to an output is not something i3 can express. `assign`
# and `for_window ... move to output` only fire when a window is created, so
# they place the terminal once and never again; a workspace switch moves the
# workspace, not the window, and the window goes with it. What is needed is a
# rule applied on every switch rather than at creation, which means watching
# i3's own events.
#
# Hence a subscriber rather than a keybinding hook. `i3-msg -t subscribe -m`
# reports every workspace focus, whatever caused it — $mod+N, a click on the
# bar, `workspace back_and_forth`, another script — so the terminal comes back
# to the panel in all of them rather than only in the one that was wired up.
#
# The mode is a flag file instead of a rebuild: it is on while an agent is
# working and off the rest of the time, which is a decision per hour and not
# per generation. The file lives in XDG_RUNTIME_DIR, so it is gone at logout
# and the session always starts in the ordinary layout.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  desktop = cfg.desktop;
  agent = desktop.agentMode;

  # The panel, by connector. `dock.internal` already names it for the layout
  # half of this, and having one answer to "which screen is the laptop's"
  # keeps the two from drifting apart.
  output = if agent.output != null then agent.output else desktop.dock.internal;

  flag = ''"''${XDG_RUNTIME_DIR:-/tmp}/i3-agent-mode"'';

  exemptNumbers = lib.concatMapStringsSep " " toString agent.exempt;

  # Move the terminal to whatever the panel is currently showing.
  #
  # The target is read as "the visible workspace on that output" rather than
  # computed from the workspace number that was just pressed. The state is
  # queried after the switch either way, so reading it is both shorter and
  # correct under things that never went through a keybinding at all —
  # including the paired-workspace script, which issues three workspace
  # commands per keypress and would otherwise have to be taught to say which
  # of them was the panel's.
  pin = pkgs.writeShellApplication {
    name = "i3-agent-terminal";
    runtimeInputs = [
      pkgs.i3
      pkgs.jq
    ];
    text = ''
      if [ ! -e ${flag} ]; then
        exit 0
      fi

      output=${lib.escapeShellArg output}

      # Nothing to pin to when the panel is off — which is the docked state
      # under `dock.keepInternal = false`, and briefly the case mid-hotplug.
      target=$(i3-msg -t get_workspaces \
        | jq -r --arg o "$output" 'first(.[] | select(.output == $o and .visible) | .name) // empty')
      if [ -z "$target" ]; then
        exit 0
      fi

      # The workspaces agent mode keeps its hands off, by the number the key
      # says rather than by the name i3 knows — the panel's half of a pair is
      # "20:10" and the monitor's is "10", and both are $mod+0. Switching to
      # one of these leaves each screen with its own contents, terminal
      # included: it is the pair you go to when the thing being looked at
      # needs both screens and the agent is not the point.
      #
      # The list goes through a variable rather than straight into the
      # `case` subject: interpolated there it is a constant, and
      # writeShellApplication runs shellcheck, which fails the build on
      # SC2194 for exactly that.
      exempt=${lib.escapeShellArg exemptNumbers}
      logical=''${target#*:}
      case " $exempt " in
        *" $logical "*) exit 0 ;;
      esac

      # The first terminal, and the workspace it is on, out of one tree query
      # so the two cannot disagree.
      #
      # "First" is by X window id, not by tree order: ids are handed out in
      # creation order and never change, while a container's place in the
      # tree changes every time anything is moved — including by this script,
      # which would then pick a different window on the next switch. The
      # scratchpad is excluded because __i3_scratch is a workspace like any
      # other as far as the tree is concerned, and a terminal deliberately
      # hidden there is not the one being supervised.
      found=$(i3-msg -t get_tree | jq -r --arg c ${lib.escapeShellArg agent.terminalClass} '
        [ recurse(.nodes[]?, .floating_nodes[]?)
          | select(.type == "workspace" and (.name | startswith("__i3") | not))
          | . as $ws
          | recurse(.nodes[]?, .floating_nodes[]?)
          | select(.window != null and .window_properties.class == $c)
          | { id, window, ws: $ws.name } ]
        | sort_by(.window)
        | if length == 0 then "" else "\(.[0].id) \(.[0].ws)" end')

      if [ -z "$found" ]; then
        exit 0
      fi

      con=''${found%% *}
      current=''${found#* }

      # Already there. Worth the check: `move container to workspace` on a
      # window that is already on it is not a no-op — i3 re-parents it next
      # to whatever is focused — so running this on every workspace event
      # would reshuffle the panel's layout continuously.
      if [ "$current" = "$target" ]; then
        exit 0
      fi

      # Focus follows a moved container when the container is the focused
      # one, so pinning the terminal while it is in use would drag the
      # session onto the panel. Noted before the move and restored after,
      # and only when it actually changed.
      focused=$(i3-msg -t get_workspaces \
        | jq -r 'first(.[] | select(.focused) | .output) // empty')

      i3-msg "[con_id=$con] move container to workspace \"$target\"" > /dev/null

      if [ -n "$focused" ]; then
        now=$(i3-msg -t get_workspaces \
          | jq -r 'first(.[] | select(.focused) | .output) // empty')
        if [ "$now" != "$focused" ]; then
          i3-msg "focus output \"$focused\"" > /dev/null
        fi
      fi
    '';
  };

  toggle = pkgs.writeShellApplication {
    name = "i3-agent-mode";
    runtimeInputs = [
      pkgs.libnotify
      pin
    ];
    text = ''
      case "''${1:-toggle}" in
        toggle)
          if [ -e ${flag} ]; then rm -f ${flag}; state=off; else : > ${flag}; state=on; fi
          ;;
        on)  : > ${flag}; state=on ;;
        off) rm -f ${flag}; state=off ;;
        status)
          if [ -e ${flag} ]; then echo on; else echo off; fi
          exit 0
          ;;
        *)
          echo "usage: i3-agent-mode [toggle|on|off|status]" >&2
          exit 2
          ;;
      esac

      # The bar is on the monitor only (`barOutputs = [ "primary" ]`), so a
      # mode with no visible indicator anywhere is a mode you forget is on.
      # -h string:x-dunst-stack-tag replaces the previous one rather than
      # stacking a column of them while the key is being pressed.
      notify-send --app-name=i3 --icon=utilities-terminal \
        -h string:x-dunst-stack-tag:agent-mode \
        "Agent mode $state" \
        "$(if [ "$state" = on ]; then
             printf 'Terminal pinned to %s' ${lib.escapeShellArg output}
           else
             printf 'Terminal follows the workspace again'
           fi)"

      # Turning it on should not wait for the next workspace switch to mean
      # something.
      if [ "$state" = on ]; then
        i3-agent-terminal || true
      fi
    '';
  };
in
{
  config = lib.mkIf (desktop.enable && agent.enable) {
    # i3.nix binds $mod+Shift+a to this. Passed through an internal option
    # rather than imported, so that the i3 config has no opinion about
    # whether the feature is built — same shape as _resolvedWallpaper.
    nixstart.home.desktop._agentModeToggle = lib.getExe toggle;

    home.packages = [
      toggle
      pin
    ];

    # In the launcher as well as on $mod+Shift+a.
    #
    # vicinae searches desktop entries, so a .desktop file is the whole of
    # the integration — nothing in the launcher's own configuration has to
    # name this one.
    #
    # Worth knowing where it lands, because it is not where the option name
    # suggests: home-manager's xdg.desktopEntries does not write into
    # ~/.local/share/applications at all. It builds each entry as a package
    # and adds it to home.packages, which under `useUserPackages` puts it in
    # /etc/profiles/per-user/<user>/share/applications — the first of the
    # paths listed in home/desktop/vicinae.nix, and the one its comment
    # already says is the one that matters here.
    #
    # NoDisplay is deliberately not set. It would keep the entry out of
    # application menus, and the launcher is an application menu — the point
    # is for "toggle agent mode" to be findable by typing it.
    xdg.desktopEntries.agent-mode = {
      name = "Toggle agent mode";
      genericName = "Pin the terminal to the laptop screen";
      comment = "Keep the agent's terminal on ${output} through every workspace switch";
      exec = lib.getExe toggle;
      icon = "utilities-terminal";
      terminal = false;
      categories = [ "Utility" ];
      # What someone actually types to find it, none of which is in the name.
      settings.Keywords = "agent;terminal;ghostty;pin;monitor;workspace;";
    };

    systemd.user.services.i3-agent-terminal = {
      Unit = {
        Description = "Keep the agent terminal on the built-in panel while agent mode is on";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # `-m` is what makes i3-msg stay on the socket and print an event per
        # line instead of answering once and exiting. It does exit when i3
        # restarts — $mod+Shift+r, or the `i3-msg restart` at the end of
        # scripts/apply.sh — which is what Restart is for.
        #
        # Only "focus" is acted on. A switch also emits "init" for a
        # workspace that did not exist yet, but init is always followed by
        # the focus that created it, and the pin reads live state rather than
        # the event, so handling both would only do the same work twice.
        ExecStart = pkgs.writeShellScript "i3-agent-terminal-watch" ''
          # Coalesced rather than one pin per event. A paired switch is
          # three i3 commands and emits a focus event for each, so $mod+N
          # arrives here as a burst — and a pin run against a half-applied
          # switch is reading the panel's *old* workspace. Waiting for the
          # events to stop means the state being read is the settled one,
          # and the window moves once per keypress instead of twice.
          ${lib.getExe pkgs.i3}-msg -t subscribe -m '["workspace"]' \
            | while :; do
                if IFS= read -r -t 0.15 event; then
                  case "$(printf '%s' "$event" | ${lib.getExe pkgs.jq} -r '.change // empty')" in
                    focus) pending=1 ;;
                  esac
                  continue
                else
                  # In the else branch on purpose. `$?` after a bare
                  # `if ...; fi` whose condition failed is the *if
                  # statement's* status, which bash defines as 0 when no
                  # branch ran — not the status of the condition. Read from
                  # there, every timeout looks like a clean socket close,
                  # the loop breaks on the first quiet 150ms, and the
                  # service goes on looking healthy for ever: bash is still
                  # waiting on the i3-msg at the head of the pipeline, so
                  # there is a live process, no restart, and nothing
                  # reading the events it prints.
                  status=$?
                fi

                # Timed out (>128) means the burst has stopped and more is
                # coming; EOF (1) means i3 went away and the service should
                # be restarted. The pin owed from the burst happens first
                # either way, exactly once.
                if [ "''${pending:-0}" = 1 ]; then
                  ${lib.getExe pin} || true
                  pending=0
                fi
                if [ "$status" -le 128 ]; then
                  break
                fi
              done
        '';
        Restart = "always";
        RestartSec = 2;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
