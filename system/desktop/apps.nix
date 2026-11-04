# The graphical applications.
{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # browsers
    firefox
    google-chrome

    # chat and meetings
    slack
    discord
    zoom-us
    telegram-desktop

    # notes, api, db
    obsidian
    postman
    beekeeper-studio
    transmission_4

    # media and images
    vlc
    gimp

    # system
    btop
    fastfetch
    gnome-system-monitor
    gnome-tweaks
    gparted
    filezilla
    cameractrls
    piper # the Logitech mouse configurator, with its ratbagd below
  ];

  # The file manager. The module rather than `xfce.thunar` in the list
  # above: it is what registers the plugins and Thunar's own D-Bus and
  # systemd user units. Thunar is the only XFCE piece here — i3 is the
  # session, so nothing else brings the rest of XFCE along.
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-volman # removable media; drives the udisks2 below
      thunar-archive-plugin # "Extract Here" in the context menu
    ];
  };

  # Thunar on its own lists files and little else. gvfs is trash, network
  # shares and phones over MTP; tumbler draws the thumbnails; udisks2 is
  # what volman actually calls to mount a USB stick. With no desktop
  # environment, nothing else turns them on.
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.udisks2.enable = true;

  services.ratbagd.enable = true;
  programs.dconf.enable = true;
}
