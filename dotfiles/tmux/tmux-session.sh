#!/usr/bin/env bash
# Modal session jump/create, launched from a tmux popup (prefix + n).
# Enter switches to that session, creating it first if it doesn't exist.
# Escape, Ctrl-C or an empty line aborts.

export INPUTRC="${BASH_SOURCE[0]%.sh}.inputrc"

read -e -p '  ' name || exit 0
[ -n "$name" ] || exit 0

# "=name" forces an exact match rather than a prefix/fnmatch one
if ! tmux has-session -t "=$name" 2>/dev/null; then
  project_dir="$HOME/dev/$name"
  if [ -d "$project_dir" ]; then
    cwd="$project_dir"
  else
    cwd=$(tmux display-message -p '#{pane_current_path}')
  fi
  tmux new-session -d -s "$name" -c "$cwd"
fi
tmux switch-client -t "=$name"
exit 0
