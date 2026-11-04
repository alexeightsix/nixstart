# git. The gh credential helper is a store path (there is no /usr/bin/gh).
{
  config,
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
