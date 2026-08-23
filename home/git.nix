# git.
#
# The credential helper was `!/usr/bin/gh auth git-credential`. That absolute
# path is the single most portable-looking line in the repository and the one
# most certain to break here: there is no /usr/bin/gh on NixOS. It resolves to
# a store path now, which also means the helper and the gh that answers it are
# always the same build.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  programs.git = {
    enable = true;
    settings = {
      user.name = cfg.user.fullName;
      user.email = cfg.user.email;

      init.defaultBranch = "main";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      advice.skippedCherryPicks = false;
    };
  };

  # .gitconfig set core.pager and interactive.diffFilter to delta by hand;
  # the module does both, and keeps the two in step.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n and N move between diff sections
      dark = false; # or light = true, or omit for auto-detection
    };
  };

  programs.gh = {
    enable = true;
    # Emits exactly the pattern the tracked .gitconfig had — an empty `helper =`
    # to clear anything inherited, then `!<gh> auth git-credential` — for both
    # github.com and gist.github.com, with gh's own store path.
    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };
  };
  programs.lazygit.enable = true;
}
