# What `link.sh --headless` linked: everything that is as useful over ssh on a
# box with no display as it is on the desktop.
#
# The reason link.sh grew a --headless flag is worth remembering: before it
# existed, the desktop bootstrap and the Incus provisioning each kept their
# own list, and they had already drifted — an instance linked tmux.conf and
# the desktop did not. One module set, two profiles, no second list.
{
  kickstart.home = {
    checkout = "/home/alex/dotfiles";
    desktop.enable = false;
    languages = [
      "go"
      "node"
    ];
    agents = true;
  };

  home.stateVersion = "25.05";
}
