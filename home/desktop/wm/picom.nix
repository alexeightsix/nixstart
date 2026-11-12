# picom.
{
  ...
}:
{
  xdg.configFile."picom/picom.conf".text = ''
    vsync = true;
    backend = "glx";
  '';
}
