# The `jbl` alias, as something the launcher can find.
#
# `jbl` is a zsh function in dotfiles/zsh/alias/jbl — power the radio on,
# connect the JBL Go 4, wait for PipeWire to publish its node, make it the
# default sink and drag whatever is already playing onto it. The third of the
# three audio modes, and the reasoning is desktop/bluetooth-headphones.nix's
# in full: a desktop entry is the whole of the integration, vicinae indexes
# ~/.local/share/applications (see the `paths` list in desktop/vicinae.nix),
# and the function stays in the alias directory so that editing it changes
# what the launcher runs with no rebuild.
#
# In a terminal, like `bt` and unlike `sp`. The two bluetooth modes share
# _audio_bt_connect, which retries a connection for up to twenty seconds and
# reaches for sudo when the radio is soft-blocked or bluetooth.service is down
# — both of which need a window, the first to narrate into and the second to
# prompt on. `sp` only ever talks to daemons that are already up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  aliasDir = "${cfg.checkout}/dotfiles/zsh/alias";

  connect = pkgs.writeShellApplication {
    name = "jbl-speaker";
    runtimeInputs = [
      pkgs.zsh
      pkgs.coreutils # mktemp, tail, sleep
      pkgs.gnugrep
      pkgs.bluez # bluetoothctl
      pkgs.util-linux # rfkill
      pkgs.wireplumber # wpctl
      pkgs.pipewire # pw-dump, pw-metadata
      pkgs.jq
      pkgs.libnotify
      pkgs.systemd # systemctl
    ];
    text = ''
      # Two files, not one: `jbl` is a three-line call into the shared
      # _audio_bt_connect, which `_audio` defines. The login shell has both
      # because it sources the whole directory; this has to name them. Spelled
      # out rather than globbed so that a rename fails here, loudly, instead of
      # in a notification body.
      helpers=${lib.escapeShellArg "${aliasDir}/_audio"}
      alias_file=${lib.escapeShellArg "${aliasDir}/jbl"}

      for f in "$helpers" "$alias_file"; do
        if [ ! -r "$f" ]; then
          notify-send --app-name=Audio --icon=bluetooth --urgency=critical \
            "JBL Go 4" "$f is missing — is the checkout where nixstart.home.checkout says it is?"
          exit 1
        fi
      done

      # Teed rather than captured: the run can take ~20s of retries and the
      # function narrates it, so it goes to the terminal as it happens and the
      # same text becomes the notification body once it is over. sudo prompts
      # on /dev/tty and is unaffected by the pipe.
      log="$(mktemp)"
      trap 'rm -f "$log"' EXIT

      # The paths go in as arguments rather than spliced into the command
      # string: $0 is the shell's own name, so $1 and $2 are the files.
      if zsh -c 'source "$1"; source "$2"; jbl' jbl-speaker "$helpers" "$alias_file" 2>&1 | tee "$log"; then
        notify-send --app-name=Audio --icon=bluetooth \
          -h string:x-dunst-stack-tag:audio-output \
          "JBL Go 4" "$(tail -n1 "$log")"
      else
        notify-send --app-name=Audio --icon=bluetooth --urgency=critical \
          -h string:x-dunst-stack-tag:audio-output \
          "JBL Go 4" "$(tail -n1 "$log")"

        # The window is the only place the reason exists in full, and it would
        # otherwise close on the spot. Only on failure: a connection that
        # worked has nothing left to read.
        printf '\nPress enter to close.'
        read -r _ || true
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ connect ];

    # Named "jbl" first for the same reason the other two are named "bt" and
    # "sp": that is the name the command has, and typing it into the launcher
    # is the muscle memory this replaces. A prefix match on the title does not
    # depend on whether the provider indexes Keywords.
    xdg.desktopEntries.jbl-speaker = {
      name = "jbl — JBL Go 4 Speaker";
      genericName = "Bluetooth Speaker";
      comment = "Connect the JBL Go 4 and make it the default audio output";
      icon = "bluetooth-active-symbolic";
      exec = "${lib.getExe config.programs.ghostty.package} -e ${lib.getExe connect}";
      terminal = false;
      categories = [
        "Audio"
        "AudioVideo"
        "Settings"
      ];
      settings.Keywords = "jbl;go;speaker;bluetooth;wireless;audio;output;sink;connect;mode;";
    };
  };
}
