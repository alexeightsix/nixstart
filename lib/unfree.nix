# The unfree allowlist, by name rather than a blanket allowUnfree.
#
# stage-01 and stage-04 pulled these in from Google's rpm repo, Flathub and
# vendor repos with no record of which were proprietary. Naming them is the
# record.
lib: pkg:
let
  name = lib.getName pkg;
in
builtins.elem name [
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

# The Android SDK, which is one licence spread over seventeen derivations.
#
# Listing them by name is what the rest of this file does and it is the wrong
# shape here. androidenv gives the archives it fetches the bare names from
# Google's repository manifest — `tools`, `platforms`, `cmake`, `emulator`,
# `ndk` — so an allowlist naming those would quietly admit any unfree package
# that ever calls itself `cmake`, and it would need editing again the moment
# pkgs/android-sdk asks for a component it does not currently pull in.
#
# All seventeen do share one thing: androidenv builds them from a single `meta`
# with this homepage, the archives included. Keying on that names the SDK
# once, which is the number of decisions actually being recorded.
#
# Accepting the licence is separate and deliberately not here — androidenv
# reads `config.android_sdk.accept_license`, set in flake.nix.
|| (pkg.meta.homepage or "") == "https://developer.android.com/tools"
