# picom. Two lines, and i3config exec'd it with an absolute path into
# $HOME/kickstart/dotfiles/picom.conf.
{
  ...
}:
{
  xdg.configFile."picom/picom.conf".text = ''
    vsync = true;
    backend = "glx";
  '';
}
