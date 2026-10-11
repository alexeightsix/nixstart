# The launcher.
#
# Same shape as flameshot: vicinae's own documentation says the file "may be
# written to by vicinae when a configuration change is made through the GUI",
# so it is seeded rather than linked.
#
# The application-search paths were a list of Fedora and Flatpak locations.
# On NixOS the desktop entries a user can launch live in the two XDG_DATA_DIRS
# home-manager and the system profile manage, so those replace the /usr ones.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;
  helpers = import ../lib.nix { inherit lib config; };

  settings = {
    "$schema" = "https://vicinae.com/schemas/config.json";
    close_on_focus_loss = false;
    pop_to_root_on_close = true;
    font.normal.family = "JetBrainsMono Nerd Font";
    theme.dark.name = "rose-pine";
    telemetry.system_info = false;
    launcher_window.compact_mode.enabled = true;

    providers = {
      "@knoopx/store.vicinae.github".preferences = {
        defaultIssueFilter = "my-issues";
        defaultRepositoryFilter = "my";
        numberOfResults = "50";
      };
      applications.preferences.defaultAction = "launch";
      # /etc/profiles/per-user is the one that matters and the one that was
      # missing. `home-manager.useUserPackages` puts home.packages there
      # rather than in ~/.nix-profile, so every application installed by a
      # home module — ghostty, neovim, and now the bt entry — lives under it,
      # while ~/.nix-profile/share/applications does not exist on this
      # machine at all. It stays in the list anyway: it is where the same
      # packages land with useUserPackages off, and a path that is not there
      # costs nothing.
      applications.preferences.paths = [
        "/etc/profiles/per-user/${cfg.user.name}/share/applications"
        "${config.home.homeDirectory}/.nix-profile/share/applications"
        "${config.home.homeDirectory}/.local/share/applications"
        "/run/current-system/sw/share/applications"
        "/var/lib/flatpak/exports/share/applications"
      ];
      calculator.enabled = false;
      manage-shortcuts.entrypoints.create.enabled = true;
      scripts.preferences.customDirs = [ "${cfg.dotfiles}/../dev-env-scripts/vicinae" ];
      shortcuts = {
        enabled = true;
        entrypoints = {
          "sct-3da3227dfafd".enabled = true;
          "sct-4608af26bfbe".enabled = true;
        };
      };
    };
  };

  json = (pkgs.formats.json { }).generate "vicinae-settings.json" settings;
in
{
  config = lib.mkIf cfg.desktop.enable {
    home.packages = [ pkgs.vicinae ];

    home.activation.seedVicinae = helpers.mkSeededFile {
      target = "${config.xdg.configHome}/vicinae/settings.json";
      source = json;
    };
  };
}
