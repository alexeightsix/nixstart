# A full desktop account, applied without NixOS underneath it.
{
  kickstart.home = {
    checkout = "/home/alex/kickstart";

    desktop.enable = true;
    desktop.statusBar = "desktop";

    languages = [
      "go"
      "node"
      "php"
      "rust"
      "lua"
      "python"
    ];
    agents = true;
  };

  home.stateVersion = "25.05";
}
