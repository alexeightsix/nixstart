{
  description = "kickstart-nix — Alex's workstation, as NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Machine-local secrets: .zsh_secrets, and the sync-dev host and password
    # that scripts/sync-dev.sh and ssh-dev-storage.sh each re-implement a
    # reader for.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The dotfiles repository — the other half of this configuration.
    #
    # Files Nix reads at build time (tmux.conf, the zellij layouts, the alias
    # files, copyline) come from here as a store path, so they are pinned by
    # the lockfile like any other input. Trees that must stay editable at
    # runtime — the Neovim config, the Pi extension set — do not; those are
    # `kickstart.home.checkout`, a plain path on the machine.
    #
    # While iterating on the dotfiles themselves:
    #   nixos-rebuild switch --flake . --override-input dotfiles path:/home/alex/kickstart
    dotfiles = {
      url = "git+ssh://git@github.com/alexeightsix/dev-env.git";
      flake = false;
    };

    # Declarative Flathub, for the applications that genuinely ship no other
    # way. stage-04's eight are all in nixpkgs.
    nix-flatpak.url = "github:gmodena/nix-flatpak";

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
          config.allowUnfreePredicate = import ./lib/unfree.nix lib;
        };

      # ---------------------------------------------------------- system ---
      # A machine: the system modules, plus the one host file that holds the
      # handful of facts true of that machine and no other. home-manager comes
      # along as a NixOS module so `nixos-rebuild switch` does both halves.
      mkHost =
        {
          hostname,
          system ? "x86_64-linux",
        }:
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs self; };
          modules = [
            { nixpkgs.pkgs = pkgsFor system; }
            ./system
            ./hosts/${hostname}
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

      # ------------------------------------------------------------ home ---
      # The same home modules, standalone. This is what `link.sh --headless`
      # was for: an account on a machine this repository does not own — the
      # Fedora desktop during the migration, the dev box, an Incus instance.
      # `home-manager switch --flake .#alex@headless`.
      mkHome =
        {
          profile,
          system ? "x86_64-linux",
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = { inherit inputs self; };
          modules = [
            ./home
            ./profiles/${profile}.nix
          ];
        };
    in
    {
      nixosConfigurations = {
        desktop = mkHost { hostname = "desktop"; };
        laptop = mkHost { hostname = "laptop"; };
      };

      homeConfigurations = {
        "alex@desktop" = mkHome { profile = "workstation"; };
        "alex@headless" = mkHome { profile = "headless"; };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) fury-renegade-rgb dracula-zsh-theme;
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              nixd
              nixfmt
              home-manager
              sops
              age
            ];
          };
        }
      );
    };
}
