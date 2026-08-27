#!/usr/bin/env bash
# Commit and push changes from one target repository every second.
set -u

if [ "$#" -ne 1 ]; then
	printf 'usage: %s <target-directory>\n' "${0##*/}" >&2
	exit 64
fi

target_dir=$(cd -- "$1" 2>/dev/null && pwd -P) || {
	printf 'auto-push: target directory does not exist: %s\n' "$1" >&2
	exit 66
}

if ! git -C "$target_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	printf 'auto-push: target is not a Git repository: %s\n' "$target_dir" >&2
	exit 65
fi

export GIT_TERMINAL_PROMPT=0
printf 'auto-push: watching %s\n' "$target_dir"

while true; do
	if git -C "$target_dir" add . && ! git -C "$target_dir" diff --cached --quiet; then
		git -C "$target_dir" commit -m 'sync' && git -C "$target_dir" push
	fi
	sleep 1
done
