# One file per alias, named after it, under the dotfiles checkout's zsh/alias/.
#
# The convention is deliberate — "a name you cannot grep for by filename is a
# name you forget you defined" — and more than half of those files are shell
# functions with fzf pipelines in them, which Nix could only hold as opaque
# strings. So the directory stays the source of truth and is sourced at
# runtime. What moves here is the handful whose *meaning* changed on NixOS.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.nixstart.home;
in
{
  programs.zsh.initContent = lib.mkOrder 550 ''
    for alias_file in ${cfg.checkout}/dotfiles/zsh/alias/*(N); do
      source "$alias_file"
    done
    unset alias_file
  '';

  programs.zsh.shellAliases = {
    # `dnf` was aliased to take a snapper snapshot and then run dnf, because a
    # Fedora package transaction cannot be undone. Both halves are one command
    # here, and its rollback is a boot menu entry.
    rebuild = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/nixstart#$(hostname)";
    rebuild-test = "sudo nixos-rebuild test --flake ${config.home.homeDirectory}/nixstart#$(hostname)";
    generations = "nixos-rebuild list-generations";

    # scripts/update-packages.sh ran nine updaters in sequence — dnf, atuin,
    # claude, opencode, codex, pi, flatpak, npm -g, rustup, cargo-update, go
    # install, oh-my-zsh, lazy.nvim — each with its own idea of "current".
    # One lockfile moves now.
    update = "nix flake update --flake ${config.home.homeDirectory}/nixstart && rebuild";

    # The whole cycle, in the order the pieces actually depend on each other:
    # move the lockfile, build and activate it, then reclaim what that
    # superseded. `update` above stops after the rebuild; this is that plus the
    # collection, for when the store has grown rather than as a routine.
    #
    # The collection is deliberately --delete-older-than 30d rather than -d.
    # `-d` removes every older generation, which is the rollback target for the
    # generation this alias just built and has not yet proven — and a
    # generation that builds is not a generation that boots. 30d matches the
    # policy nix.gc already runs weekly, so this only pulls that sweep forward.
    sync-laptop = "nix flake update --flake ${config.home.homeDirectory}/nixstart && rebuild && sudo nix-collect-garbage --delete-older-than 30d";

    # `zsh` opened ~/.zshrc and re-sourced it. That file is a store path now,
    # so the thing to edit is the module that generates it.
    zsh = "nvim ${config.home.homeDirectory}/nixstart/home/shell/zsh.nix";
  };

  # The binaries the alias files shell out to. `ls` is eza, `md` is glow, `lg`
  # is lazygit, `or`/`pr` are gh, `ff` needs fd, `dff`/`gc`/`gcm`/`gr` need fzf.
  home.packages = with pkgs; [
    eza
    fd
    ripgrep
    fzf
    glow-rose-pine
    lazygit
    gh
    delta
    vhs

    # stage-01 odds and ends that belong to no toolchain in particular.
    jq
    gettext
    ncdu
    witr # "why is this running?" — traces a process/port/container to its origin
    btop
    htop # kickstart only ever installed btop; htop added on request
    fastfetch
    tree
    unzip
  ];
}
