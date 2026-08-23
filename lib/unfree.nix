# The unfree allowlist, by name rather than a blanket allowUnfree.
#
# stage-01 and stage-04 pulled these in from Google's rpm repo, Flathub and
# vendor repos with no record of which were proprietary. Naming them is the
# record.
lib: pkg:
builtins.elem (lib.getName pkg) [
  "google-chrome"
  "slack"
  "zoom"
  "discord"
  "discord-unwrapped"
  "obsidian"
  "postman"
  "beekeeper-studio"
  "claude-code"
  "intelephense"
  "via"
  "vscode-extension-github-copilot"
]
