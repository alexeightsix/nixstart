# Claude Code plugins.
#
# `claude plugin install figma@claude-plugins-official` does two separable
# things: it clones the plugin into ~/.claude/plugins/cache and it writes an
# `enabledPlugins` entry into ~/.claude/settings.json. Only the second half is
# configuration. The first is a git checkout under a version directory, with
# an .in_use marker and a prune/update schedule claude runs itself, so it has
# no business in the store.
#
# This module owns the declaration and leaves claude the checkout: the wanted
# plugins are listed here, activation merges them into settings.json, and any
# that are not installed yet are fetched once. Both halves are idempotent, and
# the fetch is allowed to fail — a rebuild on a train should not abort over a
# plugin.
#
# settings.json is one of the files an application rewrites as you use it —
# theme, effortLevel and the fullscreen toggle all land there from inside the
# TUI — so it is merged rather than linked or seeded, for the reason spelled
# out above mkSeededFile in ../lib.nix. A store symlink would be read-only and
# every change made from /config would fail against it; seeding is a no-op on
# a file that is already there.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixstart.home;

  # `<plugin>@<marketplace>`, the same id the CLI takes.
  plugins = [
    "figma@claude-plugins-official"
  ];

  # claude clones the official marketplace on its own first run, but naming it
  # here means a fresh account does not depend on that having happened.
  marketplaces = {
    claude-plugins-official.source = {
      source = "github";
      repo = "anthropics/claude-plugins-official";
    };
  };

  json = pkgs.formats.json { };

  patch = json.generate "claude-plugins.json" {
    extraKnownMarketplaces = marketplaces;
    enabledPlugins = lib.genAttrs plugins (_: true);
  };

  emptySettings = json.generate "claude-settings.json" { };

  claudeDir = "${config.home.homeDirectory}/.claude";
  settings = "${claudeDir}/settings.json";
  installed = "${claudeDir}/plugins/installed_plugins.json";

  jq = lib.getExe pkgs.jq;
  claude = lib.getExe pkgs.claude-code;
in
{
  config = lib.mkIf cfg.agents {
    home.activation.claudePlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -s ${settings} ]; then
        run mkdir -p ${claudeDir}
        run install -m 0644 ${emptySettings} ${settings}
      fi

      # `*` is jq's recursive object merge, so everything claude has written
      # for itself survives and only the two keys above are ours. Through a
      # temporary file and an && so that a settings.json claude has left
      # half-written is reported rather than truncated.
      run ${jq} -s '.[0] * .[1]' ${settings} ${patch} > ${settings}.nixstart \
        && run mv ${settings}.nixstart ${settings}
      rm -f ${settings}.nixstart

      for plugin in ${lib.escapeShellArgs plugins}; do
        if ! ${jq} -e --arg p "$plugin" '.plugins[$p] // empty' ${installed} > /dev/null 2>&1; then
          run ${claude} plugin install "$plugin" \
            || warnEcho "claude plugin install $plugin failed; run it by hand when you are online"
        fi
      done
    '';
  };
}
