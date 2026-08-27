---
sidebar_position: 2
title: Install
---

# Install

## On a machine that already has kickstart

```bash
bash ~/kickstart/dotfiles/pi/link.sh
```

`link.sh` is idempotent. Anything already pointing at this repository is left alone; anything else is preserved as a timestamped `*.backup-<stamp>` before the symlink replaces it. It discovers every top-level extension, JSON theme, and skill directory automatically, so re-run it after adding one; no second inventory needs updating.

It links into `$PI_CODING_AGENT_DIR`, or `~/.pi/agent` when that is unset.

## From scratch

```bash
dnf install git
cd /home/alex && git clone https://github.com/alexeightsix/dev-env.git kickstart
sudo bash stage-01.sh
bash stage-02.sh
# ...
bash stage-03.sh   # links pi, the `burn` command, and the other editor configs
```

Pi itself is installed separately. `stage-03.sh` places the tracked `pi-launcher` at `~/.local/bin/pi`; it dispatches every invocation directly to the real Pi executable later on `PATH`, using Pi's bundled Node runtime when available. Bare `pi` starts a new session without a separate startup chooser. `link.sh` only places agent configuration. The agent-usage tool, `burn`, lives outside this repository in `~/dev/burn` (published at github.com/alexeightsix/burn); `stage-03.sh` links `~/dev/burn/burn` into `~/.local/bin/burn`, which is already on the configured shell `PATH`. Run `~/dev/burn/install.sh` to also enable its systemd user service.

## Packages

`settings.json` declares npm packages that Pi installs into `~/.pi/agent/npm`:

| Package | Why |
| --- | --- |
| `pi-vim` | Vim keybindings in the editor |
| `pi-mcp-adapter` | One proxy tool for all MCP servers instead of hundreds of tool definitions — see [MCP](./mcp.md) |
| `git:github.com/stnly/pi-grok@v0.10.1` | SuperGrok as `xai-oauth` — see [Models](./models.md) |

Pi's native startup check, `pi update`, and the tracked machine updater already cover updates. A second updater extension is deliberately not installed.

Install a new package with `pi install npm:<name>`; it writes through the `settings.json` symlink into this repository, so the change is tracked automatically.

## Language servers

The [LSP tools](./lsp.md) use language servers installed on the machine rather than Pi packages:

```bash
go install golang.org/x/tools/gopls@latest
npm install --global @typescript/native-preview
```

`@typescript/native-preview` provides `tsgo`, the native Go implementation of TypeScript. Both binaries should be available on `PATH`; the LSP extension also checks `~/go/bin/gopls` and the directory containing Pi's Node executable.

## Maintenance

Run `bash ~/kickstart/update-packages.sh` as the normal desktop user. It uses `sudo` only for system packages and firmware, while user-scoped package managers run as the desktop account. The script updates DNF-managed software (including Ghostty), Flatpaks, firmware, coding agents, Pi and its model catalog, npm globals, Rust/Cargo and Go tools, Oh My Zsh, TPM plugins, Neovim configuration/plugins, and AppImages under `/opt`.

## Verifying

```bash
pi -p --no-session --thinking off -nt "Reply with exactly: ok"
```

A clean `ok` means the config parsed, the extensions loaded, and the default provider is authenticated. Extension load failures print to stderr before the first token.
