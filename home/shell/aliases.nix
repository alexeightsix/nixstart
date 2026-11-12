# One file per alias, named after it, under the dotfiles checkout's zsh/alias/.
#
# The convention is deliberate — "a name you cannot grep for by filename is a
# name you forget you defined" — and more than half of those files are shell
# functions with fzf pipelines in them, which Nix could only hold as opaque
# strings. So the directory stays the source of truth and is sourced at
# runtime. The NixOS-specific ones are here.
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
    # vicinae indexes desktop entries once at startup and does not notice new
    # ones, so an app added by the switch stays out of the launcher until the
    # daemon restarts. `try-restart` is a no-op when it is not running.
    #
    # i3 and its bar read their config once, so a switch that changes either
    # is invisible until i3 restarts; `restart` is in place and keeps the
    # windows. `|| true` because there is no i3 to reach from a TTY or over
    # SSH, and that must not stop `update` and `sync-nix`, which chain on this.
    rebuild = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/nixstart && systemctl --user try-restart vicinae.service && (i3-msg -q restart || true)";
    rebuild-test = "sudo nixos-rebuild test --flake ${config.home.homeDirectory}/nixstart";
    generations = "nixos-rebuild list-generations";

    # Move the lockfile and rebuild.
    update = "bump-opencode && nix flake update --flake ${config.home.homeDirectory}/nixstart && rebuild";

    # The whole cycle, in the order the pieces actually depend on each other:
    # move the lockfile, build and activate it, update Pi's user-managed
    # extension packages, then reclaim what the rebuild superseded. Pi itself
    # stays Nix-managed; only its packages are updated as the normal user.
    # `update` above stops after the rebuild.
    #
    # The collection is deliberately --delete-older-than 30d rather than -d.
    # `-d` removes every older generation, which is the rollback target for the
    # generation this alias just built and has not yet proven — and a
    # generation that builds is not a generation that boots. 30d matches the
    # policy nix.gc already runs weekly, so this only pulls that sweep forward.
    sync-nix = "bump-opencode && nix flake update --flake ${config.home.homeDirectory}/nixstart && rebuild && pi update --extensions && sudo nix-collect-garbage --delete-older-than 30d";

    # The one input `nix flake update` cannot move. ghostty is pinned to an
    # explicit main revision in flake.nix precisely so the lockfile sweep
    # leaves it alone, which means bumping it is an edit to that line — this
    # is that edit, not a way around it. It rewrites the pin and stops; the
    # rebuild is still a separate, deliberate `sync-nix`.
    bump-ghostty = "rev=$(git ls-remote https://github.com/ghostty-org/ghostty main | cut -f1) && sed -i \"s|github:ghostty-org/ghostty/[0-9a-f]*|github:ghostty-org/ghostty/$rev|\" ${config.home.homeDirectory}/nixstart/flake.nix && echo \"ghostty pinned to $rev — run sync-nix to build it\"";

    # opencode is pinned to a release tag in flake.nix, so the lockfile sweep
    # cannot move it either — and unlike ghostty it is meant to stay current,
    # so `update` and `sync-nix` run this first. Upstream ships several
    # releases a day and no branch tracks them (`dev` runs ahead, `production`
    # behind), so the newest vX.Y.Z tag is the only reliable "latest".
    bump-opencode = "tag=$(git ls-remote --tags --refs https://github.com/anomalyco/opencode 'v*' | cut -d/ -f3 | grep -E '^v[0-9]+\\.[0-9]+\\.[0-9]+$' | sort -V | tail -1) && [ -n \"$tag\" ] && sed -i \"s|github:anomalyco/opencode/v[0-9.]*|github:anomalyco/opencode/$tag|\" ${config.home.homeDirectory}/nixstart/flake.nix && echo \"opencode pinned to $tag\"";

    # Powering the adapter off drops every Bluetooth connection, so the
    # headsets come back fresh rather than reattaching to a half-dead session.
    # The pause gives wireplumber's bluez monitor time to come up before the
    # adapter returns, or the devices reconnect with no audio profile.
    restart-audio = "bluetoothctl power off && systemctl --user restart pipewire pipewire-pulse wireplumber && sleep 2 && bluetoothctl power on";

    # ~/.zshrc is a store path, so edit the module that generates it.
    zsh = "nvim ${config.home.homeDirectory}/nixstart/home/shell/zsh.nix";
  };

  # The binaries the alias files shell out to. eza, lazygit, gh and fzf come
  # from their programs.* modules; fd and ripgrep from neovim.nix.
  home.packages = with pkgs; [
    glow-rose-pine
    vhs

    # Odds and ends that belong to no toolchain in particular.
    jq
    gettext
    ncdu
    witr # "why is this running?" — traces a process/port/container to its origin
    btop
    htop
    fastfetch
    tree
  ];
}
