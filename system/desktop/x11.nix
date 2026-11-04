{
  lib,
  pkgs,
  ...
}:
{
  services.xserver = {
    enable = true;
    xkb.layout = "us";

    # Caps Lock is Escape, and nothing else. A single option covers both
    # halves of that: `caps:escape` replaces the key's symbol with Escape
    # and removes it from the Lock modifier, so the LED never comes on and
    # there is no Caps Lock state left to get stuck in. It is not
    # `caps:escape` plus `caps:none` — the two set the same group and the
    # last one parsed wins, which would silently give the key no binding
    # at all.
    #
    # This is the X session only; core/locale.nix carries it into the TTYs.
    #
    # terminate:ctrl_alt_bksp is nixpkgs' own default for this option, and
    # the option is a plain comma-separated string rather than a list — so
    # assigning it replaces the default outright. It is repeated here to
    # keep Ctrl+Alt+Backspace killing the X server; dropping it from this
    # line is how that binding would quietly disappear.
    xkb.options = "terminate:ctrl_alt_bksp,caps:escape";

    displayManager.lightdm.enable = lib.mkDefault true;
    # i3 itself is configured in desktop/i3.nix; this is only the session.
    windowManager.i3.enable = true;
  };

  services.displayManager.defaultSession = "none+i3";

  services.libinput.enable = true;

  # The desktop portal. Without it `flameshot gui` (Ctrl+; in desktop/i3.nix)
  # exits with "Could not locate the `org.freedesktop.portal.Desktop` service".
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  environment.systemPackages = with pkgs; [
    xclip
    gpick
  ];
}
