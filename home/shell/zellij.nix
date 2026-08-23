# Zellij, wearing tmux's keybindings.
#
# config.kdl and the layouts were `render`ed by link.sh rather than linked,
# because they contain a literal $DOTFILES that Zellij would never expand and
# because Zellij watches the file and rewrites it — through a symlink that
# would write back into the repository.
#
# The substitution is the same one link.sh's sed pass did, done at build time.
# `pkgs.replaceVars` is the usual tool for this and is deliberately not used:
# it expects @NAME@ placeholders, and these files use shell-style $NAME, so it
# fails the build rather than silently leaving them unexpanded.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.kickstart.home;

  render =
    name: file:
    pkgs.writeText name (
      builtins.replaceStrings
        [ "$DOTFILES" "$KICKSTART" "$HOME" ]
        [ cfg.dotfiles "${cfg.dotfiles}/.." config.home.homeDirectory ]
        (builtins.readFile file)
    );

  layouts = builtins.attrNames (builtins.readDir "${cfg.dotfiles}/zellij/layouts");
in
{
  home.packages = [ pkgs.zellij ];

  xdg.configFile = {
    "zellij/config.kdl".source = render "zellij-config.kdl" "${cfg.dotfiles}/zellij/config.kdl";

    "zellij/plugins/tmux-status.wasm".source = "${cfg.dotfiles}/zellij/plugins/tmux-status.wasm";
  }
  # Zellij reads layouts from layout_dir at runtime, so a literal $DOTFILES in
  # one would never be expanded either. link.sh looped over the directory; so
  # does this, rather than naming them.
  // lib.listToAttrs (
    map (name: {
      name = "zellij/layouts/${name}";
      value.source = render "zellij-layout-${name}" "${cfg.dotfiles}/zellij/layouts/${name}";
    }) layouts
  );

  # config.kdl's prefix+r binding runs this to rename a session.
  home.file = {
    ".config/zellij/zellij-rename.sh".source = "${cfg.dotfiles}/zellij-rename.sh";
    ".config/zellij/zellij-rename.inputrc".source = "${cfg.dotfiles}/zellij-rename.inputrc";
  };
}
