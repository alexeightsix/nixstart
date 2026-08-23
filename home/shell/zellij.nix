# Zellij, wearing tmux's keybindings.
#
# config.kdl and the layouts under layouts/ were `render`ed rather than linked
# because they contain a literal $DOTFILES that Zellij would never expand —
# link.sh's comment says so. Interpolation does that here, and the layout
# directory is a store path so Zellij's own file watcher cannot write back
# into the repository.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;

  substitute =
    file:
    pkgs.replaceVars file {
      DOTFILES = cfg.dotfiles;
      HOME = config.home.homeDirectory;
    };
in
{
  home.packages = [ pkgs.zellij ];

  xdg.configFile = {
    "zellij/config.kdl".source = substitute "${cfg.dotfiles}/zellij/config.kdl";
    "zellij/layouts/tmux.kdl".source = substitute "${cfg.dotfiles}/zellij/layouts/tmux.kdl";
    "zellij/plugins/tmux-status.wasm".source = "${cfg.dotfiles}/zellij/plugins/tmux-status.wasm";
  };

  home.file = {
    ".config/zellij/zellij-rename.sh".source = "${cfg.dotfiles}/zellij-rename.sh";
    ".config/zellij/zellij-rename.inputrc".source = "${cfg.dotfiles}/zellij-rename.inputrc";
  };
}
