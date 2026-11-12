{
  description = "nixstart — Alex's workstation, as NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Machine-local secrets. See system/core/secrets.nix.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # No dotfiles input: they live in this repository at `${self}/dotfiles`.
    # Trees that must stay editable at runtime go through
    # `nixstart.home.checkout`.

    # The weather wallpaper generator — the base image with the current
    # temperature drawn on it.
    weather-wallpaper = {
      url = "github:upbeatdevelopment/wealther-wallpaper";
      flake = false;
    };

    # Pi. Not in nixpkgs, and its published npm tarball ships no lockfile,
    # which is what blocks a plain buildNpmPackage — earendil-works/pi#701.
    # This flake builds it from the tagged GitHub source with a generated
    # lockfile, autoPatchelfs the native addons and restores the provider
    # model data that is excluded from git, so the work is taken from there
    # rather than repeated here.
    #
    # Only the package is used, never the overlay: the overlay also replaces
    # claude-code and codex, which come from nixpkgs in home/dev/agents.nix
    # and are fine as they are.
    #
    # Deliberately no `inputs.nixpkgs.follows`. The derivation pins an
    # npmDepsHash computed against its own nixpkgs, and that hash does not
    # survive being rebuilt with a different npm.
    coding-agents.url = "github:kissgyorgy/coding-agents";

    # Ghostty from main rather than the tagged release. nixpkgs is not behind
    # here — it carries 1.3.1, which is the newest tag — so this is a choice to
    # track the development branch, not a workaround.
    #
    # Deliberately no `inputs.nixpkgs.follows`. Ghostty's flake pins
    # nixpkgs-unstable on purpose, for the Zig 0.16, GTK 4.22 and fontconfig
    # 2.18 its package.nix needs, and says so in its own comment. Following
    # ours would build it against a nixpkgs it is not tested against.
    #
    # The matching binary cache is in system/nix/settings.nix: ghostty's flake
    # declares it in nixConfig, but a dependency's nixConfig has no effect on
    # the flake consuming it, so it has to be repeated there or every bump
    # compiles Zig and GTK from source.
    # Pinned to an explicit main commit rather than the branch. A branch input
    # is pinned in flake.lock anyway; naming the revision here makes the
    # version visible in the file and means `nix flake update` cannot move it
    # on its own — bumping ghostty is an edit to this line.
    ghostty.url = "github:ghostty-org/ghostty/ca91d0a24e67b3eecdb23c943227cd2b3908747b";

    # opencode from its own flake rather than nixpkgs, which trails the
    # releases (2.1.4 against 2.2.4 upstream when this was added). Pinned to
    # a release tag like ghostty is pinned to a commit, so `nix flake update`
    # cannot move it; the `bump-opencode` alias rewrites this line to the newest
    # release, and `update` / `sync-nix` run it first.
    #
    # Deliberately no `inputs.nixpkgs.follows`, for the same reason as
    # coding-agents: the package carries a node_modules hash computed against
    # its own nixpkgs' bun.
    opencode.url = "github:anomalyco/opencode/v2.2.5";

    # witr — "why is this running?": traces a process, port, container or file
    # back to the chain that started it. Taken from its own flake.
    witr = {
      url = "github:pranshuparmar/witr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A fork of glow with a built-in rose-pine style, matching Ghostty, the
    # bar, vicinae and Neovim. The `md` alias is glow.
    glow-rose-pine = {
      url = "github:upbeatdevelopment/glow-rose-pine";
      flake = false;
    };

    # Rose Pine for GTK, so Thunar and the other GTK applications match
    # Ghostty, the bar, vicinae and Neovim. nixpkgs had this and removed it —
    # see packages/rose-pine-gtk-theme for what that was about — so it is built
    # from the same upstream here. The icons are still nixpkgs'
    # `rose-pine-icon-theme`, which survived.
    rose-pine-gtk-theme = {
      url = "github:Fausto-Korpsvart/Rose-Pine-GTK-Theme";
      flake = false;
    };


  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [ "x86_64-linux" ];
      forAllSystems = lib.genAttrs systems;

      overlays = [ (import ./overlays.nix inputs) ];

      pkgsFor =
        system:
        import nixpkgs {
          inherit system overlays;
          config = {
            allowUnfreePredicate = import ./lib/unfree.nix lib;

            # A second gate in front of the Android SDK, and naming a package
            # in lib/unfree.nix does not open it: androidenv reads this
            # attribute directly and every one of its derivations refuses to
            # build while it is false. It stands for having read Google's SDK
            # terms, so it is a statement about a licence rather than a build
            # flag — which is why it is here beside the allowlist and not in
            # packages/android-sdk.
            android_sdk.accept_license = true;

            # beekeeper-studio 6.1.4 bundles Electron 39.8.10, EOL since March
            # 2026 and carrying known CVEs; nixpkgs marked it insecure in the
            # 2026-09-05 bump. It is a database client pointed at hosts this
            # machine already holds credentials for, so the realistic exposure
            # is content rendered inside it, not the network. Kept rather than
            # dropped, with the risk stated. Remove this once nixpkgs ships a
            # build on a supported Electron.
            #
            # It has to live here and not in a module: `nixpkgs.pkgs` is set
            # from pkgsFor, which makes the module-level `nixpkgs.config`
            # options inert.
            permittedInsecurePackages = [ "beekeeper-studio-6.1.4" ];
          };
        };

      # ---------------------------------------------------------- system ---
      # The one machine: the system modules, plus system/machine.nix, which
      # holds the facts true of this machine. home-manager comes along as a
      # NixOS module so `nixos-rebuild switch` does both halves.
      laptop =
        let
          system = "x86_64-linux";
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.pkgs = pkgsFor system; }
            ./system
            ./system/machine.nix
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "backup";
                extraSpecialArgs = { inherit inputs self; };
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = {
        inherit laptop;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs)
            dracula-zsh-theme
            weather-wallpaper
            glow-rose-pine
            witr
            ;
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          # Working on this repository itself.
          #
          # Not `with pkgs; [ ... home-manager ... ]`: `with` binds looser than
          # the `outputs = inputs@{ self, nixpkgs, home-manager, ... }` argument
          # above, so a bare `home-manager` here resolves to the flake input —
          # an attrset, not a derivation — and the shell fails to build with
          # "Dependency is not of a valid type". Qualified, so it is the
          # package.
          nix = pkgs.mkShellNoCC {
            packages = [
              pkgs.nixd
              pkgs.nixfmt
              pkgs.home-manager
              pkgs.sops
              pkgs.age
            ];
          };
        }
      );
    };
}
