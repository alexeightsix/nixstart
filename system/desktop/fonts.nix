# stage-11 downloaded a JetBrainsMono Nerd Font release zip from GitHub and
# unpacked it into /usr/local/share/fonts, pinned to v3.2.1 by URL.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.nixstart.system.desktop.enable {
    fonts = {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
      ];

      fontconfig.defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
