# The `bt` alias, as something the launcher can find.
#
# `bt` is a zsh function in dotfiles/zsh/alias/bt — power the radio on, connect
# the Blue Matrix headphones, wait for PipeWire to publish their nodes, make
# them the default sink and source. That is only reachable from a shell, which
# means opening a terminal to connect a pair of headphones.
#
# A desktop entry makes it reachable from $mod+d instead: vicinae's
# applications provider indexes ~/.local/share/applications, which is where
# home-manager writes these (see the `paths` list in desktop/vicinae.nix), so
# the entry shows up in the launcher and in any other application menu at the
# same time.
#
# The function itself is not reimplemented here. aliases.nix sources the alias
# directory at runtime from the checkout rather than from the store — "the
# directory stays the source of truth" — and this honours that: the wrapper
# sources the same file and calls the same function, so editing the alias
# changes what the launcher runs with no rebuild.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  alias = "${cfg.checkout}/dotfiles/zsh/alias/bt";

  # zsh, not bash: the file is zsh and is written like it. `-c` is enough —
  # nothing in it needs an interactive shell, and sourcing ~/.zshrc to reach
  # one function would drag in the prompt, the theme and atuin.
  connect = pkgs.writeShellApplication {
    name = "bt-headphones";
    runtimeInputs = [
      pkgs.zsh
      pkgs.coreutils
      pkgs.bluez # bluetoothctl
      pkgs.util-linux # rfkill
      pkgs.wireplumber # wpctl
      pkgs.pipewire # pw-dump
      pkgs.jq
      pkgs.libnotify
      pkgs.systemd # systemctl
    ];
    text = ''
      alias_file=${lib.escapeShellArg alias}

      if [ ! -r "$alias_file" ]; then
        notify-send --app-name=Bluetooth --icon=bluetooth --urgency=critical \
          "Blue Matrix" "$alias_file is missing — is the checkout where nixstart.home.checkout says it is?"
        exit 1
      fi

      # Teed rather than captured: the run takes up to ~20s of retries and the
      # function narrates it, so it goes to the terminal as it happens, and the
      # same text becomes the notification body once it is over. sudo — which
      # the function only reaches for when the radio is soft-blocked or
      # bluetooth.service is down — prompts on /dev/tty and is unaffected by
      # the pipe, which is why this runs in a terminal at all.
      log="$(mktemp)"
      trap 'rm -f "$log"' EXIT

      # The path goes in as an argument rather than spliced into the command
      # string: $0 is the shell's own name, so $1 is the file.
      if zsh -c 'source "$1"; bt' bt-headphones "$alias_file" 2>&1 | tee "$log"; then
        notify-send --app-name=Bluetooth --icon=bluetooth \
          "Blue Matrix" "$(tail -n1 "$log")"
      else
        notify-send --app-name=Bluetooth --icon=bluetooth --urgency=critical \
          "Blue Matrix" "$(tail -n1 "$log")"

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

    # In a terminal window rather than `terminal = true`, which asks the
    # desktop to pick one — there is no XDG terminal association on this
    # machine and nothing would answer. Ghostty is the terminal here, and it
    # is the same `-e` form i3's $mod+w uses for nmtui.
    #
    # Named "bt" first because that is the name the command has: typing bt
    # into the launcher is the muscle memory this replaces, and a prefix match
    # on the title does not depend on whether the provider indexes Keywords.
    xdg.desktopEntries.bt-headphones = {
      name = "bt — Blue Matrix Headphones";
      genericName = "Bluetooth Headphones";
      comment = "Connect the Blue Matrix headphones and make them the default audio device";
      icon = "bluetooth";
      exec = "${lib.getExe config.programs.ghostty.package} -e ${lib.getExe connect}";
      terminal = false;
      categories = [
        "Audio"
        "AudioVideo"
        "Settings"
      ];
      settings.Keywords = "bt;bluetooth;headphones;headset;blue matrix;audio;pair;connect;";
    };
  };
}
