#!/usr/bin/env bash
# Modal session/window rename, launched from a tmux popup (prefix + r).
# Choose a target, then edit its current name. Enter commits; Escape, Ctrl-C or
# an empty line aborts.

export INPUTRC="${BASH_SOURCE[0]%.sh}.inputrc"

read -r -s -n 1 -p '  [s]ession / [w]indow: ' target || exit 0
printf '\r\033[2K'

case "$target" in
  s | S)
    cur=$(tmux display-message -p '#S')
    rename_command=(tmux rename-session --)
    ;;
  w | W)
    cur=$(tmux display-message -p '#W')
    rename_command=(tmux rename-window --)
    ;;
  *) exit 0 ;;
esac

read -e -i "$cur" -p '  ' name || exit 0
[ -n "$name" ] && "${rename_command[@]}" "$name"
exit 0
