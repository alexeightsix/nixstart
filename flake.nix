{
  description = "nixstart — Alex's workstation, as NixOS";

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

    # The dotfiles used to be a separate input — a `path:/home/alex/kickstart`
    # pointing at a dev-env checkout, because ghostty-shaders/ and
    # zsh/copyline.plugin.zsh were untracked in the dev-env remote and a git
    # input would have silently produced a configuration missing both.
    #
    # They now live in this repository, under dotfiles/ and wallpapers/, so
    # there is no input at all: `${self}/dotfiles`. That removes the last
    # reason this flake was only buildable on a machine that happened to have
    # a second checkout next to it, and the untracked files are tracked here.
    #
    # The build-time/runtime distinction survives the move. Files Nix reads at
    # build time (tmux.conf, dunstrc, the shaders) come from the store path.
    # Trees that must stay editable at runtime — the Neovim config, the Pi
    # setup — do not; those go through `nixstart.home.checkout`, a plain path
    # on the machine, which is now this repository's own working tree.

    # The weather wallpaper generator — the base image with the current
    # temperature drawn on it. Was a `go build` in a checkout under
    # ~/dev/archive with the binary committed next to its source.
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

    # jk: vim-style keyboard scrolling for X11. i3config execs it as
    # $HOME/.local/bin/jk, which is a dynamically linked ELF that was built by
    # hand and would not run on NixOS at all. It ships its own flake, so this
    # takes the package rather than repackaging it.
    jk = {
      url = "github:upbeatdevelopment/jk";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # witr — "why is this running?": traces a process, port, container or file
    # back to the chain that started it. stage-12 installed it with
    # `curl ... | bash`, which drops a binary into /usr/local/bin outside any
    # package manager. It ships its own flake, so like jk this takes the
    # package rather than repackaging it.
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
        vm = mkHost { hostname = "vm"; };
      };

      homeConfigurations = {
        "alex@desktop" = mkHome { profile = "workstation"; };
        "alex@headless" = mkHome { profile = "headless"; };
      };

      # Incus images for the agent guest. Both are built from hosts/agent, so
      # the container and the VM cannot drift apart.
      #
      #   nix build .#agent-container
      #   scripts/agent build   does the build and the import
      #   scripts/agent new foo  launches an instance from it
      # Reusable pieces, for guests built outside this flake — a microvm.nix
      # host, an Incus VM image, another machine's configuration.
      nixosModules = {
        devEnv = ./system/dev-env.nix;
        agentVm = ./profiles/agent-vm.nix;
      };

      # The dev environment as a plain function, for anything that is not a
      # NixOS module at all.
      lib.devEnv = import ./lib/dev-env.nix;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;

          # Both images come from the same guest configuration, so the
          # container and the VM cannot drift apart. nixpkgs carries the Incus
          # image modules itself — nixos-generators is deprecated for exactly
          # this, having been upstreamed.
          agentGuest =
            extra:
            lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs self; };
              # Not the whole ./system tree: that imports the home-manager
              # bridge, and a guest has no per-user generation — its dev
              # environment comes in through nixstart.devEnv instead.
              modules = [
                { nixpkgs.pkgs = pkgs; }
                ./system/options.nix
                ./system/core/nix.nix
                ./system/core/nix-ld.nix
                ./system/dev-env.nix
                ./hosts/agent
              ]
              ++ extra;
            };

          container = agentGuest [
            "${inputs.nixpkgs}/nixos/modules/virtualisation/lxc-container.nix"
            "${inputs.nixpkgs}/nixos/modules/virtualisation/lxc-image-metadata.nix"
          ];

          vm = agentGuest [
            "${inputs.nixpkgs}/nixos/modules/virtualisation/incus-virtual-machine.nix"
          ];
        in
        {
          inherit (pkgs)
            fury-renegade-rgb
            dracula-zsh-theme
            weather-wallpaper
            glow-rose-pine
            witr
            jk
            ;

          # An Incus container: shares the host kernel, boots in under a
          # second, costs almost nothing to throw away.
          agent-container = container.config.system.build.tarball;
          agent-container-metadata = container.config.system.build.metadata;

          # An Incus virtual machine: its own kernel, so code the agent runs
          # cannot reach the host through a shared one. Prefer this when the
          # agent is running code you have not read.
          agent-vm = vm.config.system.build.qemuImage;
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      # The dev shells. This is where agents are started: `nix develop
      # .#agent` gives them the same tools, aliases and shell they would have
      # on the desktop, without needing a NixOS host underneath.
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          lib = pkgs.lib;

          mkShell =
            {
              name,
              languages ? [ ],
              agents ? false,
              databases ? false,
            }:
            import ./lib/dev-shell.nix {
              inherit pkgs lib name;
              dotfiles = "${self}/dotfiles";
              devEnv = import ./lib/dev-env.nix {
                inherit
                  pkgs
                  lib
                  languages
                  agents
                  databases
                  ;
              };
            };
        in
        {
          # Everything, for working on a project by hand.
          default = mkShell {
            name = "dev";
            languages = [
              "go"
              "node"
              "rust"
              "lua"
              "python"
            ];
            databases = true;
          };

          # What an agent is launched into. Same shell, plus the agents
          # themselves.
          agent = mkShell {
            name = "agent";
            languages = [
              "go"
              "node"
            ];
            agents = true;
          };

          # One per language, for a micro VM that only does one thing.
          go = mkShell {
            name = "go";
            languages = [ "go" ];
            agents = true;
          };
          node = mkShell {
            name = "node";
            languages = [ "node" ];
            agents = true;
          };

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
