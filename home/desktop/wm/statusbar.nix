# i3status-rust.
{
  config,
  lib,
  pkgs,
  ...
}:
let

  # Rosé Pine: the bar's background, its text, and the dimmed text for
  # things that are off.
  base = "#191724";
  text = "#e0def4";
  muted = "#6e6a86";

  rosePine = {
    theme = "plain";
    # One flat surface: every state sits on the bar's own base, and colour
    # is spent on the text only when something wants attention. Idle, info
    # and good all read as plain text — a CPU at 30% or a full battery is
    # not news. Amber and red are the only signals.
    #
    # No separator and no background changes between blocks, so the only
    # spacing is each block's own one-space padding: every gap in the bar
    # is the same two spaces.
    overrides = {
      idle_bg = base;
      idle_fg = text;
      info_bg = base;
      info_fg = text;
      good_bg = base;
      good_fg = text;
      warning_bg = base;
      warning_fg = "#f6c177";
      critical_bg = base;
      critical_fg = "#eb6f92";
      separator = "";
      separator_bg = "auto";
      separator_fg = "auto";
    };
  };

  # The headset is old enough that it cannot carry music and the microphone
  # at once: A2DP is stereo playback with no mic, HFP is the mic with
  # telephone-grade audio. Which one is active decides whether a Meet call
  # can hear you or whether music sounds like a call, so the bar shows it.
  #
  # Only the first bluez device is read: one headset is ever connected.
  # `{text: ""}` with no device lets `hide_when_empty` drop the block, where
  # empty output would fail to parse as JSON.
  btProfile = pkgs.writeShellApplication {
    name = "bt-profile";
    runtimeInputs = [
      pkgs.pipewire # pw-dump
      pkgs.jq
    ];
    text = ''
      pw-dump | jq -c '
        [ .[] | select(.type == "PipeWire:Interface:Device" and .info.props["device.api"] == "bluez5")
              | .info.params.Profile[0]? // empty ]
        | if length == 0 then {text: ""}
          else first
            | ((.description | capture("codec (?<c>[^)]+)").c) // "") as $codec
            | if (.name | startswith("a2dp")) then {state: "Good", text: "A2DP"}
              elif (.name | startswith("headset")) then {state: "Warning", text: "HFP"}
              else {state: "Idle", text: .name} end
            | .text += (if $codec == "" then "" else " \($codec)" end)
            | .icon = "headphones"
          end'
    '';
  };

  # Flips between the two: on HFP it goes to the best available A2DP
  # profile, otherwise to HFP. "Best" is PipeWire's own priority, the same
  # ranking it uses to pick a profile on connect, so this lands where a
  # fresh connection would.
  btProfileToggle = pkgs.writeShellApplication {
    name = "bt-profile-toggle";
    runtimeInputs = [
      pkgs.pipewire # pw-dump
      pkgs.wireplumber # wpctl
      pkgs.jq
    ];
    text = ''
      target="$(pw-dump | jq -r '
        [ .[] | select(.type == "PipeWire:Interface:Device" and .info.props["device.api"] == "bluez5") ]
        | first // empty
        | .id as $id
        | (if (.info.params.Profile[0].name | startswith("headset")) then "a2dp" else "headset" end) as $want
        | [ .info.params.EnumProfile[] | select(.available != "no" and (.name | startswith($want))) ]
        | max_by(.priority) // empty
        | "\($id) \(.index)"')"
      [ -n "$target" ] || exit 0
      read -r id index <<<"$target"
      wpctl set-profile "$id" "$index"
    '';
  };

  # Just the lock: bright while connected, dimmed when stopped, amber when it
  # wants a login. The exit node's name is the only text, and only while
  # traffic goes through one. A daemon that is not running at all reads as
  # stopped rather than leaving the block without JSON.
  tailscaleStatus = pkgs.writeShellApplication {
    name = "tailscale-status";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.jq
    ];
    text = ''
      { tailscale status --json 2>/dev/null || echo '{}'; } | jq -c '
        (first(.Peer[]? | select(.ExitNode) | .HostName) // null) as $exit
        | if .BackendState == "Running" then
            {state: "Good", text: (if $exit then " \($exit)" else "" end)}
          elif .BackendState == "NeedsLogin" then {state: "Warning", text: ""}
          else {state: "Idle", text: ""} end
        | .icon = "net_vpn"'
    '';
  };

  # Agents running in the herdr app, counted by what they need from you, in
  # herdr's own marks and colours so the bar reads like its sidebar. Its
  # Rosé Pine theme takes them from the palette (the Win98 theme spells the
  # mapping out): waiting (an approval or question is on screen) a red dot,
  # which also turns the robot red; done (a finished turn nobody has looked
  # at yet) a foam dot; working a gold ring. The colours are Pango spans,
  # which the block's `pango-str()` passes through as markup rather than
  # escaping.
  #
  # This asks herdr-core, the server behind the app, and not the `herdr`
  # TUI's server, which is a separate program that is not running here.
  # Unread is herdr's own rule: a terminal's `herdr.seen` label holds the
  # last turn the app showed you, so a done terminal whose turn is past it
  # is one you have not looked at. `ls` does not carry labels, hence a
  # `get` per done terminal. With nothing to count, or no server, the block
  # disappears.
  #
  # herdr's working ring has a bright arc running round it. The font has no
  # rotated arcs to draw that with, so the ring pulses instead, from herdr's
  # own dim ring colour up to the gold and back, over four seconds. i3bar
  # cannot animate, so the block reruns every half second and picks the
  # step from the clock. Only the colour changes, never the glyph, so
  # nothing on the bar shifts. Asking herdr-core twice a second would be
  # waste, so the counts are cached and only refetched when two seconds
  # old; the steps in between are a `jq` over the cache.
  herdrCache = "\${XDG_RUNTIME_DIR:-/tmp}/herdr-status.json";
  pulse = [
    "#634f3a"
    "#8a6c48"
    "#b48d58"
    "#d9a968"
    "#f6c177"
    "#d9a968"
    "#b48d58"
    "#8a6c48"
  ];
  herdrStatus = pkgs.writeShellApplication {
    name = "herdr-status";
    runtimeInputs = [
      pkgs.herdr-app # herdr-core
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      cache="${herdrCache}"
      if [ ! -s "$cache" ] || [ $(($(date +%s) - $(stat -c %Y "$cache"))) -ge 2 ]; then
        if ls="$(herdr-core ls --json 2>/dev/null)"; then
          unread=0
          while read -r t; do
            if herdr-core get --json "$t" 2>/dev/null \
              | jq -e '.turn > ((.labels["herdr.seen"] // "0") | tonumber)' >/dev/null; then
              unread=$((unread + 1))
            fi
          done < <(jq -r '.terminals[] | select(.status == "done") | .address' <<<"$ls")
          jq -c --argjson unread "$unread" '
            [ .terminals[] | .status // empty ] as $s
            | { waiting: ($s | map(select(. == "blocked" or . == "waiting")) | length),
                unread: $unread,
                working: ($s | map(select(. == "working")) | length) }' <<<"$ls" > "$cache.tmp"
        else
          echo '{}' > "$cache.tmp"
        fi
        mv "$cache.tmp" "$cache"
      fi
      steps=(${lib.escapeShellArgs pulse})
      ring="''${steps[$(( $(date +%s%N) / 500000000 % ''${#steps[@]} ))]}"
      jq -c --arg ring "$ring" '
        def tint($c): "<span foreground=\"\($c)\">\(.)</span>";
        (.waiting // 0) as $waiting | (.unread // 0) as $unread | (.working // 0) as $working
        | [ (if $waiting > 0 then ("󰝥" | tint("#eb6f92")) + " \($waiting) waiting" else empty end),
            (if $unread > 0 then ("󰝥" | tint("#9ccfd8")) + " \($unread) done" else empty end),
            (if $working > 0 then ("󰝦" | tint($ring)) + " \($working) working" else empty end) ]
        | if length == 0 then {text: ""}
          else {text: join("  "), icon: "agent", state: (if $waiting > 0 then "Critical" else "Idle" end)}
          end' "$cache"
    '';
  };

  # Clicking the herdr block takes you to the agent that most wants you:
  # the first one waiting, else the first unread done one, by the same rules
  # as the count. The app shows its pane (`agent.focus`, which also marks a
  # done turn read and so takes it off the count), then i3 focuses the app's
  # window, which switches to whichever workspace it is on. With nothing to
  # go to, it just brings up the window. The cache goes, so the count the
  # block redraws with after the click is fresh.
  herdrFocus = pkgs.writeShellApplication {
    name = "herdr-focus";
    runtimeInputs = [
      pkgs.herdr-app # herdr-app, herdr-core
      pkgs.jq
      pkgs.i3
    ];
    text = ''
      target=""
      if ls="$(herdr-core ls --json 2>/dev/null)"; then
        target="$(jq -r 'first(.terminals[] | select(.status == "blocked" or .status == "waiting") | .address) // empty' <<<"$ls")"
        if [ -z "$target" ]; then
          while read -r t; do
            if herdr-core get --json "$t" 2>/dev/null \
              | jq -e '.turn > ((.labels["herdr.seen"] // "0") | tonumber)' >/dev/null; then
              target="$t"
              break
            fi
          done < <(jq -r '.terminals[] | select(.status == "done") | .address' <<<"$ls")
        fi
      fi
      if [ -n "$target" ]; then
        # Quoted: unquoted, shellcheck reads `do` as the loop keyword.
        herdr-app "do" agent.focus --terminal "$target" >/dev/null
      fi
      i3-msg -q '[class="herdr-app"] focus'
      rm -f "${herdrCache}"
    '';
  };

  # Every block pads itself with exactly one space each side and nothing
  # else, so the gaps stay even.
  blocks = [
    {
      block = "custom";
      command = lib.getExe herdrStatus;
      json = true;
      hide_when_empty = true;
      interval = 0.5; # for the working pulse; see herdrStatus
      format = " $icon $text.pango-str() ";
      # Its own panel, Rosé Pine overlay against the bar's base, at the left
      # end: agents are the one part of the bar that is about your work
      # rather than the machine.
      theme_overrides = {
        idle_bg = "#26233a";
        critical_bg = "#26233a";
      };
      click = [
        {
          button = "left";
          cmd = lib.getExe herdrFocus;
          update = true;
        }
      ];
    }
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
      block = "cpu";
      info_cpu = 20;
      warning_cpu = 50;
      critical_cpu = 90;
      format = " $icon $utilization ";
    }
    {
      block = "temperature";
      # The hottest sensor is the one that matters; the average next to it
      # was half the bar's width for no decision it ever changed.
      format = " $icon $max ";
    }
    {
      block = "memory";
      format = " $icon $mem_total_used_percents.eng(w:2) ";
      format_alt = " $icon_swap $swap_used_percents.eng(w:2) ";
    }
    {
      block = "custom";
      command = lib.getExe btProfile;
      json = true;
      hide_when_empty = true;
      interval = 5;
      # The default format is `{$icon }$text`, with no padding, which runs
      # the block into its neighbours; the others all pad with a space.
      format = " $icon $text ";
      # A2DP in the headset's own blue — its midnight navy lifted until it
      # reads on the dark bar — so it is "the headset" at a glance. The only
      # coloured text that is not a warning. HFP keeps the amber.
      theme_overrides.good_fg = "#8ea6d9";
      # `update` reruns the command right after the click, so the new
      # profile shows at once instead of on the next 5s tick.
      click = [
        {
          button = "left";
          cmd = lib.getExe btProfileToggle;
          update = true;
        }
      ];
    }
    {
      block = "net";
      # Just which link carries traffic: the wifi or ethernet glyph (see
      # `icons` below), or a struck-out network when there is none. nmtui is
      # a click away for the network's name.
      #
      # `missing_format` is a literal glyph rather than `$icon`: the block
      # leaves the icon unset when there is no device, and the line then
      # fails as "Failed to render full text" rather than falling back.
      format = " $icon ";
      missing_format = " 󰲛 "; # nf-md-network_off
      click = [
        {
          button = "left";
          cmd = "${lib.getExe config.programs.ghostty.package} -e ${lib.getExe' pkgs.networkmanager "nmtui"}";
        }
      ];
    }
    {
      block = "custom";
      command = lib.getExe tailscaleStatus;
      json = true;
      interval = 10;
      # `$text` is empty or " <exit node>", so no space before it here.
      format = " $icon$text ";
      theme_overrides.idle_fg = muted;
    }
    {
      block = "time";
      interval = 5;
      format = " $timestamp.datetime(f:'%a %-d %b %H:%M') ";
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
        icons = {
          icons = "awesome4";
          # awesome4 has no ethernet glyph and draws wired as a globe, and has
          # nothing for an agent. These are Material Design icons from the
          # Nerd Font the bar uses; `agent` is a new name, used by the herdr
          # block above.
          overrides = {
            net_wired = "󰈀"; # nf-md-ethernet
            net_wireless = "󰖩"; # nf-md-wifi
            agent = "󰚩"; # nf-md-robot
          };
        };
        block = blocks;
      };
}
