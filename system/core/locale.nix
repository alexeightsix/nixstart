{ lib, ... }:
{
  time.timeZone = lib.mkDefault "America/Toronto";
  i18n.defaultLocale = lib.mkDefault "en_CA.UTF-8";
  console.keyMap = lib.mkDefault "us";

  # Build the console keymap from the X keyboard configuration instead of
  # loading a stock one, so `caps:escape` in desktop/x11.nix applies in the
  # TTYs too — otherwise Caps Lock is Escape in the session and still Caps
  # Lock on VT2.
  #
  # This defines console.keyMap itself, at normal priority, which is why the
  # line above is mkDefault: the generated keymap wins over it rather than
  # colliding with it.
  console.useXkbConfig = true;
}
