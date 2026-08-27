#!/usr/bin/env bash
# Exercise the launcher and worker against an isolated tmux server and Git remote.
set -euo pipefail

skill_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
export HOME=$tmp/home
export XDG_STATE_HOME=$tmp/state
export TMUX_TMPDIR=$tmp/tmux
unset TMUX
mkdir -p "$HOME" "$TMUX_TMPDIR"
chmod 700 "$TMUX_TMPDIR"

cleanup() {
	tmux kill-server >/dev/null 2>&1 || true
	rm -rf -- "$tmp"
}
trap cleanup EXIT

repo=$tmp/repo
remote=$tmp/remote.git
git init --bare -q "$remote"
git init -q -b main "$repo"
git -C "$repo" config user.name 'Auto Push Test'
git -C "$repo" config user.email 'auto-push@example.test'
git -C "$repo" remote add origin "$remote"
printf 'initial\n' >"$repo/value.txt"
git -C "$repo" add .
git -C "$repo" commit -qm initial
git -C "$repo" push -qu origin main
printf 'first\n' >"$repo/value.txt"

# No tmux server means no runtime worker and no target changes.
"$skill_dir/scripts/start.sh" "$repo"
[ ! -e "$XDG_STATE_HOME/pi/auto-push.sh" ]
[ "$(git -C "$repo" status --porcelain)" = ' M value.txt' ]

tmux new-session -d -s prerequisite 'sleep 30'
out=$("$skill_dir/scripts/start.sh" "$repo")
printf '%s\n' "$out" | grep -Eq 'auto-push: started .* in automations:@[0-9]+ pane %[0-9]+'
worker_pane=$(printf '%s\n' "$out" | grep -oE 'pane %[0-9]+' | cut -d' ' -f2)
[ -x "$XDG_STATE_HOME/pi/auto-push.sh" ]
tmux has-session -t automations
tmux list-panes -t automations -F '#{pane_id}' | grep -Fxq "$worker_pane"

for _ in $(seq 1 50); do
	[ "$(git --git-dir="$remote" show main:value.txt 2>/dev/null || true)" = 'first' ] && break
	sleep 0.1
done
[ "$(git --git-dir="$remote" show main:value.txt)" = 'first' ]

tmux capture-pane -p -t "$worker_pane" | grep -Fq "auto-push: watching $repo"
printf 'auto-push tests: ok\n'
