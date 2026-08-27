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

  # Same two links as the NixOS hosts — see hosts/laptop/default.nix.
  nixstart.neovim.linkConfig = true;
  nixstart.pi.linkConfig = true;

  home.stateVersion = "25.05";
}
