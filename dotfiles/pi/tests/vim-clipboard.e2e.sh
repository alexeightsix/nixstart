#!/usr/bin/env bash
# Real clipboard regression for the global pi-vim wrapper.
set -euo pipefail

for command in pi tmux xclip; do
	command -v "$command" >/dev/null || {
		echo "vim clipboard e2e requires $command" >&2
		exit 1
	}
done
[ -n "${DISPLAY:-}" ] || {
	echo "vim clipboard e2e requires DISPLAY" >&2
	exit 1
}

artifacts=$(mktemp -d /tmp/vim-clipboard-test.XXXXXX)
witness_extension="$artifacts/witness.ts"
sessions=()
cleanup() {
	for session in "${sessions[@]}"; do
		tmux kill-session -t "$session" 2>/dev/null || true
	done
	rm -rf "$artifacts"
}
trap cleanup EXIT

cat >"$witness_extension" <<'TS'
import { appendFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
export default function (pi: ExtensionAPI) {
	pi.on("input", (event) => {
		const path = process.env.VIM_WITNESS_PATH;
		if (!path) throw new Error("VIM_WITNESS_PATH is required");
		appendFileSync(path, `${JSON.stringify(event.text)}\n`);
		return { action: "handled" };
	});
}
TS

start_pi() {
	local tag=$1
	SESSION="vim-clip-$tag-$RANDOM"
	WITNESS="$artifacts/$tag.events"
	sessions+=("$SESSION")
	tmux new-session -d -s "$SESSION" -x 120 -y 35 \
		"cd /tmp && VIM_WITNESS_PATH='$WITNESS' PI_OFFLINE=1 pi --approve --no-session -e '$witness_extension'"
	sleep 3
}

submit() {
	local expected=$1
	tmux send-keys -t "$SESSION" Escape
	sleep 0.1
	tmux send-keys -t "$SESSION" ':'
	tmux send-keys -t "$SESSION" w
	tmux send-keys -t "$SESSION" Enter
	for _ in $(seq 1 20); do
		[ -e "$WITNESS" ] && break
		sleep 0.1
	done
	[ "$(cat "$WITNESS")" = "\"$expected\"" ]
}

start_pi bracketed
printf BRACKETED_PASTE | tmux load-buffer -
tmux paste-buffer -p -t "$SESSION"
sleep 0.2
submit BRACKETED_PASTE
echo "ok bracketed terminal paste"

start_pi ctrl-v
printf SYSTEM_CLIPBOARD_PASTE | xclip -selection clipboard -in -target UTF8_STRING
sleep 0.1
tmux send-keys -t "$SESSION" C-v
sleep 0.7
tmux capture-pane -p -t "$SESSION" >"$artifacts/ctrl-v.pane"
grep -Eq 'SYSTEM_CLIPBOARD_PASTE|/tmp/pi-clipboard-[[:alnum:]-]+\.png' "$artifacts/ctrl-v.pane"
echo "ok Ctrl+V system clipboard paste"

start_pi yank
tmux send-keys -t "$SESSION" YANK_MIRROR
sleep 0.1
tmux send-keys -t "$SESSION" Escape
sleep 0.1
tmux send-keys -t "$SESSION" 0
tmux send-keys -t "$SESSION" y
tmux send-keys -t "$SESSION" '$'
value=""
for _ in $(seq 1 30); do
	value=$(xclip -selection clipboard -out 2>/dev/null || true)
	[ "$value" = YANK_MIRROR ] && break
	sleep 0.1
done
[ "$value" = YANK_MIRROR ]
echo "ok Vim yank mirrors to system clipboard"

start_pi put
printf PUT_FROM_CLIPBOARD | xclip -selection clipboard -in -target UTF8_STRING
sleep 0.1
tmux send-keys -t "$SESSION" Escape
sleep 0.1
tmux send-keys -t "$SESSION" p
sleep 0.3
submit PUT_FROM_CLIPBOARD
echo "ok Vim put reads system clipboard"
