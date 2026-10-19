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

  # `agent-apply` on PATH, execing the script in the working checkout.
  #
  # A thin wrapper rather than the script inlined into the store, and
  # deliberately: the point of this one is that an agent can edit the
  # configuration and then apply it, and a store copy could only ever apply
  # the version of itself that was built — so fixing agent-apply would
  # require an agent-apply that already worked. Reading it from the checkout
  # at run time breaks that circle, and matches what `checkout` is for
  # everywhere else in this repository.
  #
  # tmux is named here rather than assumed: the script is started by an agent
  # whose environment is whatever spawned it, and the one thing it cannot do
  # without is the session it runs the rebuild in.
  agentApply = pkgs.writeShellApplication {
    name = "agent-apply";
    runtimeInputs = [
      pkgs.tmux
      pkgs.coreutils
    ];
    text = ''
      exec ${cfg.checkout}/scripts/agent-apply.sh "$@"
    '';
  };
in
{
  config = lib.mkIf cfg.agents {
    # grok-cli is in nixpkgs now, so `grok` comes from the store like the other
    # three. It was previously carried as a PATH entry pointing at ~/.grok/bin,
    # where its curl installer had put a Node application on Fedora — but
    # nothing on a NixOS install ever creates that directory, so the export and
    # the fpath line beside it silently added nothing and `grok` was the one
    # agent that simply was not installed. The package ships bin/grok and no
    # zsh completions, so the fpath line has no replacement and is dropped
    # rather than left pointing at a path that will never exist.
    home.packages = [
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
      pkgs.grok-cli

      # Applying a nix change is part of an agent's work here, not something
      # handed back to be run by hand. See scripts/agent-apply.sh for what it
      # does about the two things that otherwise stop it — the terminal dying
      # mid-rebuild, and a sudo prompt nothing can answer.
      agentApply
    ];
  };
}
