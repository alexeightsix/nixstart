# The `sp` alias, as something the launcher can find.
#
# `sp` is a zsh function in dotfiles/zsh/alias/sp — power the bluetooth radio
# down, make the built-in speakers and microphone the defaults, and move the
# streams that are already playing onto them. The reasoning is desktop/
# bluetooth-headphones.nix's, in the other direction: a desktop entry is the
# whole of the integration, vicinae indexes it, and the function itself stays
# in the alias directory so that editing it changes what the launcher runs
# with no rebuild.
#
# Not in a terminal, which is the one place this differs from `bt`. That one
# retries a connection for up to twenty seconds and reaches for sudo when the
# radio is blocked, so it needs a window to narrate into. This one talks to a
# bluetoothd and a PipeWire that are already running, takes about a second,
# and has nothing to say that does not fit in the notification.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  aliasDir = "${cfg.checkout}/dotfiles/zsh/alias";

  switch = pkgs.writeShellApplication {
    name = "sp-laptop-speakers";
    runtimeInputs = [
      pkgs.zsh
      pkgs.coreutils # mktemp, cut, tail
      pkgs.gnugrep
      pkgs.bluez # bluetoothctl
      pkgs.wireplumber # wpctl
      pkgs.pipewire # pw-dump, pw-metadata
      pkgs.jq
      pkgs.libnotify
    ];
    text = ''
      # Two files, not one: `sp` calls the stream-moving helpers that `_audio`
      # defines, and the login shell only has them because it sources the
      # whole directory. Spelled out rather than globbed so that a rename
      # fails here, loudly, instead of in a notification body.
      helpers=${lib.escapeShellArg "${aliasDir}/_audio"}
      alias_file=${lib.escapeShellArg "${aliasDir}/sp"}

      for f in "$helpers" "$alias_file"; do
        if [ ! -r "$f" ]; then
          notify-send --app-name=Audio --icon=audio-speakers --urgency=critical \
            "Laptop speakers" "$f is missing — is the checkout where nixstart.home.checkout says it is?"
          exit 1
        fi
      done

      # Captured rather than teed: there is no terminal to narrate into, and
      # the function's last line is written to be the notification body.
      log="$(mktemp)"
      trap 'rm -f "$log"' EXIT

      # The paths go in as arguments rather than spliced into the command
      # string: $0 is the shell's own name, so $1 and $2 are the files.
      if zsh -c 'source "$1"; source "$2"; sp' sp-laptop-speakers "$helpers" "$alias_file" > "$log" 2>&1; then
        notify-send --app-name=Audio --icon=audio-speakers \
          -h string:x-dunst-stack-tag:audio-output \
          "Laptop speakers" "$(tail -n1 "$log")"
      else
        notify-send --app-name=Audio --icon=audio-speakers --urgency=critical \
          -h string:x-dunst-stack-tag:audio-output \
          "Laptop speakers" "$(tail -n1 "$log")"
        exit 1
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ switch ];

    # Named "sp" first for the same reason the bluetooth entry is named "bt":
    # that is the name the command has, and typing it into the launcher is the
    # muscle memory this replaces. A prefix match on the title does not depend
    # on whether the provider indexes Keywords.
    xdg.desktopEntries.laptop-speakers = {
      name = "sp — Laptop Speakers Mode";
      genericName = "Laptop Speakers";
      comment = "Bluetooth off, built-in speakers and mic default, playing streams moved over";
      icon = "audio-speakers";
      exec = lib.getExe switch;
      terminal = false;
      categories = [
        "Audio"
        "AudioVideo"
        "Settings"
      ];
      settings.Keywords = "sp;speakers;laptop;internal;builtin;audio;output;sink;bluetooth;off;disconnect;headphones;mode;";
    };
  };
}
