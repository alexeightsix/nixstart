#!/usr/bin/env bash
# Link the tracked Pi configuration into the default (global) Pi agent directory.
# Idempotent: anything already pointing at this repository is left alone, anything
# else is preserved as a timestamped .backup-* before the symlink is created.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
timestamp=$(date +%Y%m%d-%H%M%S)

link() {
	local relative=$1
	local source="$repo_root/$relative"
	local target="$agent_dir/$relative"
	local expected current backup

	if [ ! -e "$source" ]; then
		echo "link.sh: missing $source" >&2
		return 1
	fi

	expected=$(realpath "$source")
	mkdir -p "$(dirname "$target")"

	if [ -L "$target" ]; then
		current=$(realpath "$target" 2>/dev/null || true)
		if [ "$current" = "$expected" ]; then
			echo "  ok       $relative"
			return 0
		fi
		backup="${target}.backup-${timestamp}"
		mv -- "$target" "$backup"
		echo "  backup   $relative -> $(basename "$backup")"
	elif [ -e "$target" ]; then
		backup="${target}.backup-${timestamp}"
		mv -- "$target" "$backup"
		echo "  backup   $relative -> $(basename "$backup")"
	fi

	ln -s "$source" "$target"
	echo "  linked   $relative"
}

prune_removed_links() {
	local directory=$1
	local target source

	[ -d "$agent_dir/$directory" ] || return 0
	for target in "$agent_dir/$directory"/*; do
		[ -L "$target" ] || continue
		source=$(readlink "$target")
		case "$source" in
			"$repo_root/$directory/"*)
				if [ ! -e "$source" ]; then
					rm -- "$target"
					echo "  removed  $directory/$(basename "$target")"
				fi
				;;
		esac
	done
}

echo "pi: linking into $agent_dir"

# Automatic discovery needs symmetric uninstall behavior: removing a tracked
# extension must remove its installed symlink rather than leave a dangling,
# still-discovered entry behind.
prune_removed_links extensions
prune_removed_links themes
prune_removed_links skills

link settings.json
link keybindings.json
link mcp.json
link APPEND_SYSTEM.md
link lib

for source in "$repo_root"/themes/*.json; do
	link "themes/$(basename "$source")"
done
for source in "$repo_root"/extensions/*; do
	link "extensions/$(basename "$source")"
done
for source in "$repo_root"/skills/*; do
	[ -d "$source" ] && link "skills/$(basename "$source")"
done

echo "pi: done. Run 'pi' to pick up the config, or /reload inside a session."
