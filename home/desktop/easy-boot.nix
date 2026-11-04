# scripts/easy-boot.sh, as something the launcher can find: "Toggle easy boot"
# on $mod+d, the same shape as "Toggle agent mode" in agent-mode.nix, and
# opened in Ghostty the way bluetooth-headphones.nix opens `bt`.
#
# The wrapper runs the script from the checkout rather than the store, for two
# reasons. Editing it then needs no rebuild. And the script finds apply.sh and
# system/easy-boot-flag.nix relative to itself, so it has to be the copy in
# the working tree, not a store path.
#
# In a terminal because it cannot run without one: sudo asks for the account
# password, and turning it on asks for the disk passphrase through cryptsetup.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  script = "${cfg.checkout}/scripts/easy-boot.sh";

  easy-boot = pkgs.writeShellApplication {
    name = "easy-boot";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      script=${lib.escapeShellArg script}

      if [ ! -x "$script" ]; then
        notify-send --app-name="Easy boot" --icon=dialog-password --urgency=critical \
          "Easy boot" "$script is missing — is the checkout where nixstart.home.checkout says it is?"
        exit 1
      fi

      # From a shell, a plain pass-through: `easy-boot on|off|toggle|status`.
      [ -n "''${EASY_BOOT_LAUNCHER:-}" ] || exec "$script" "$@"

      # From the launcher: say how it went, and on failure keep the window
      # open, since the build output is the only place the reason is.
      if "$script" "$@"; then
        state="$("$script" status | head -n1 | awk '{ print $2 }')"
        notify-send --app-name="Easy boot" --icon=dialog-password \
          "Easy boot $state" "Takes effect on the next startup."
      else
        notify-send --app-name="Easy boot" --icon=dialog-password --urgency=critical \
          "Easy boot" "Toggle failed. See the terminal."
        printf '\nPress enter to close.'
        read -r _ || true
      fi
    '';
  };
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ easy-boot ];

    xdg.desktopEntries.easy-boot = {
      name = "Toggle easy boot";
      genericName = "Skip the boot passwords";
      comment = "No disk passphrase and no login password from the next startup, or back again";
      icon = "dialog-password";
      exec = "${lib.getExe config.programs.ghostty.package} -e env EASY_BOOT_LAUNCHER=1 ${lib.getExe easy-boot} toggle";
      terminal = false;
      categories = [
        "System"
        "Settings"
      ];
      settings.Keywords = "easy boot;autologin;auto login;luks;encryption;password;passphrase;boot;";
    };
  };
}
