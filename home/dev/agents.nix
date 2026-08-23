# Coding agents.
#
# Every one arrived through its own curl-to-bash installer or npm global —
# stage-15 for claude, and PATH lines in .zshrc for opencode
# (~/.opencode/bin), a global npm prefix (~/.npm-global/bin) and grok
# (~/.grok/bin, with its own compinit block at the end of the file).
# update-packages.sh then called four different `update` subcommands to keep
# them current.
#
# Pi is the fifth and is handled separately, in pi.nix — it is a working
# checkout, not a package.
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
  config = lib.mkIf cfg.agents {
    home.packages = with pkgs; [
      claude-code
      codex
      opencode
    ];

    # grok-cli is not in nixpkgs. Its installer puts a Node application in
    # ~/.grok, which is exactly the kind of thing nix-ld exists for, so the
    # PATH entry and the completions are kept rather than pretending the tool
    # is gone. .zshrc ended with this block; it ends up in the same place.
    programs.zsh.initContent = lib.mkOrder 1200 ''
      if [ -d "$HOME/.grok/bin" ]; then
        export PATH="$HOME/.grok/bin:$PATH"
        fpath=("$HOME/.grok/completions/zsh" $fpath)
      fi
    '';
  };
}
