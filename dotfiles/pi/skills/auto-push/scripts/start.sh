#!/usr/bin/env bash
# Install and start the auto-push worker in the shared automation session.
set -euo pipefail

if [ "$#" -ne 1 ]; then
	printf 'usage: %s <target-directory>\n' "${0##*/}" >&2
	exit 64
fi

# A running tmux server is the opt-in boundary for background automation.
if ! command -v tmux >/dev/null 2>&1 || ! tmux list-sessions >/dev/null 2>&1; then
	exit 0
fi

target_dir=$(cd -- "$1" 2>/dev/null && pwd -P) || {
	printf 'auto-push: target directory does not exist: %s\n' "$1" >&2
	exit 66
}

if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	printf 'auto-push: target is not a Git repository: %s\n' "$target_dir" >&2
	exit 65
fi

skill_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/pi
worker=$state_dir/auto-push.sh
mkdir -p -- "$state_dir"
if [ ! -e "$worker" ]; then
	install -m 700 -- "$skill_dir/assets/auto-push.sh" "$worker"
fi

session=automations
window_name=auto-push-$(basename -- "$target_dir")
if tmux has-session -t "$session" 2>/dev/null; then
	location=$(tmux new-window -d -P -F '#{window_id} #{pane_id}' -t "$session" -n "$window_name" -c "$target_dir" "$worker" "$target_dir")
else
	location=$(tmux new-session -d -P -F '#{window_id} #{pane_id}' -s "$session" -n "$window_name" -c "$target_dir" "$worker" "$target_dir")
fi
read -r window_id pane_id <<<"$location"

printf 'auto-push: started %s in %s:%s pane %s\n' "$target_dir" "$session" "$window_id" "$pane_id"
