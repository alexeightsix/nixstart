# A full desktop account, applied without NixOS underneath it.
{
  nixstart.home = {
    checkout = "/home/alex/nixstart";

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
