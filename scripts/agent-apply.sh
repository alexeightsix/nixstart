#!/usr/bin/env bash
# Apply this configuration from inside a coding agent.
#
#   agent-apply            apply live  (switch — the default here)
#   agent-apply boot       stage for the next boot
#   agent-apply test       apply live, leave the boot menu alone
#
# scripts/apply.sh is the real thing and this does not replace it. What this
# adds is the two properties an agent needs and an interactive shell does not:
#
# 1. The rebuild outlives the terminal it was started from. apply.sh ends by
#    restarting i3 and the user services, and a change that moves the system
#    path restarts display-manager — which kills X, every terminal on it, and
#    a rebuild still halfway through activation. An agent's shell is one of
#    those terminals. So the work happens in a detached tmux session, which
#    belongs to the tmux server rather than to any terminal, and survives
#    both. Output is followed from outside and printed as it arrives, so the
#    agent still sees the build; it simply is not what is holding it up.
#
# 2. It never waits on a password. See the NOPASSWD rule in
#    system/core/users.nix — without it `sudo nixos-rebuild` blocks on a
#    prompt nothing will ever answer, and the preflight below says so in one
#    line instead of hanging for an hour.
#
# `switch` rather than apply.sh's `boot` default, because the point of an
# agent applying a change is to find out whether it works.
set -euo pipefail

MODE="${1:-switch}"
case "$MODE" in
    boot|switch|test) ;;
    *) echo "usage: $(basename "$0") [switch|boot|test]" >&2; exit 2 ;;
esac

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="agent-apply"
RUNDIR="${XDG_RUNTIME_DIR:-/tmp}/agent-apply"
LOG="$RUNDIR/log"
RC="$RUNDIR/rc"

step() { printf '\n\033[1;32m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m==> %s\033[0m\n' "$*" >&2; }

# --- one at a time ---------------------------------------------------------
# Two nixos-rebuilds against the same profile is a race over /nix/var/nix/
# profiles/system, and the loser's generation is the one that silently does
# not exist. An already-running session is followed rather than duplicated.
if tmux has-session -t "$SESSION" 2>/dev/null; then
    step "an apply is already running — following it"
    tail -n +1 -f "$LOG" --pid="$$" &
    tail_pid=$!
    while tmux has-session -t "$SESSION" 2>/dev/null; do sleep 2; done
    kill "$tail_pid" 2>/dev/null || true
    exit "$(cat "$RC" 2>/dev/null || echo 1)"
fi

# --- preflight: sudo -------------------------------------------------------
# -l asks whether the command is permitted, -n makes the question itself
# non-interactive. Both are needed: the NOPASSWD rule covers nixos-rebuild
# specifically, so a bare `sudo -n true` tests a privilege this user does not
# have and would report failure on a correctly configured machine.
if ! sudo -n -l /run/current-system/sw/bin/nixos-rebuild >/dev/null 2>&1; then
    fail "sudo would ask for a password, and nothing here can answer it."
    fail "The NOPASSWD rule in system/core/users.nix is not on this generation yet."
    fail "Run this once by hand, then agent-apply works from then on:"
    fail "    $REPO/scripts/apply.sh switch"
    exit 1
fi

mkdir -p "$RUNDIR"
: > "$LOG"
rm -f "$RC"

# --- run it ----------------------------------------------------------------
# The inner shell is bash -lc rather than the command alone: tmux runs it
# through $SHELL otherwise, which is zsh here and brings the whole interactive
# configuration with it. `pipefail` so the recorded status is the rebuild's
# and not tee's, which always succeeds.
step "applying ($MODE) in tmux session '$SESSION'"
tmux new-session -d -s "$SESSION" \
    "bash -lc 'set -o pipefail; \"$REPO/scripts/apply.sh\" \"$MODE\" 2>&1 | tee \"$LOG\"; echo \$? > \"$RC\"'"

# --- follow it -------------------------------------------------------------
# --pid so the tail dies with this script if the agent is interrupted, rather
# than being left reading a file nobody will write to again.
tail -n +1 -f "$LOG" --pid="$$" &
tail_pid=$!

while tmux has-session -t "$SESSION" 2>/dev/null; do
    sleep 2
done

# tee's last write and tail's last read are not ordered by the session ending.
sleep 1
kill "$tail_pid" 2>/dev/null || true
wait "$tail_pid" 2>/dev/null || true

# --- close it --------------------------------------------------------------
# The session has normally exited with its command. This is for the case where
# it has not — an apply.sh that spawned something still holding the pane open.
tmux kill-session -t "$SESSION" 2>/dev/null || true

rc="$(cat "$RC" 2>/dev/null || echo 1)"
if [ "$rc" = 0 ]; then
    step "applied ($MODE)"
else
    fail "apply failed (exit $rc) — the log above is the whole of it, and is"
    fail "also at $LOG"
fi
exit "$rc"
