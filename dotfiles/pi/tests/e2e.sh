#!/usr/bin/env bash
# End-to-end tests against the real binaries: pi, Node, language servers, tmux.
#
#   ./tests/e2e.sh          everything that costs nothing
#   ./tests/e2e.sh --paid   also the tests that spend real tokens
#
# These are deliberately not mocked. The failures worth catching here — an
# extension that throws on load, a symlink that does not resolve, a provider
# that is not authenticated — only happen against the real thing.
set -uo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
paid=0
[ "${1:-}" = "--paid" ] && paid=1

pass=0
fail=0
skip=0

ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n%s\n' "$1" "${2:-}"; fail=$((fail + 1)); }
miss() { printf '  \033[33mskip\033[0m  %s (%s)\n' "$1" "$2"; skip=$((skip + 1)); }

echo "e2e: $repo_root"

# --- config integrity -------------------------------------------------------

echo
echo "config"

for file in settings.json mcp.json keybindings.json themes/rose-pine.json; do
	if python3 -c "import json,sys;json.load(open('$repo_root/$file'))" 2>/dev/null; then
		ok "$file is valid JSON"
	else
		bad "$file is valid JSON"
	fi
done

if ! grep -Eqi 'claude|anthropic' "$repo_root/settings.json" &&
	! find "$repo_root/extensions" -maxdepth 1 -type f -iname '*claude*' -print -quit | grep -q .; then
	ok "tracked runtime config has no Claude integration"
else
	bad "tracked runtime config has no Claude integration"
fi

if grep -Fq '# Coding-first operating mode' "$repo_root/APPEND_SYSTEM.md" &&
	grep -Fq 'Act as a coding assistant unless the user explicitly asks for another kind of work.' "$repo_root/APPEND_SYSTEM.md" &&
	grep -Fq 'plausibly belongs to a different project' "$repo_root/APPEND_SYSTEM.md" &&
	! grep -Fq 'What kind of project is this, and what is it for?' "$repo_root/APPEND_SYSTEM.md"; then
	ok "global prompt is coding-first without a startup questionnaire"
else
	bad "global prompt is coding-first without a startup questionnaire"
fi

if out=$(python3 "$repo_root/tests/pi-launcher.test.py" "$repo_root/pi-launcher" 2>&1); then
	ok "bare interactive pi starts a new session directly"
else
	bad "bare interactive pi starts a new session directly" "$out"
fi

# link.sh must be idempotent, prune removed tracked resources, and never touch
# anything outside the target dir.
tmp_agent=$(mktemp -d)
mkdir -p "$tmp_agent/extensions"
ln -s "$repo_root/extensions/removed-test-extension.ts" "$tmp_agent/extensions/removed-test-extension.ts"
if PI_CODING_AGENT_DIR="$tmp_agent" bash "$repo_root/link.sh" >/dev/null 2>&1; then
	first=$(find "$tmp_agent" -type l | sort)
	PI_CODING_AGENT_DIR="$tmp_agent" bash "$repo_root/link.sh" >/dev/null 2>&1
	second=$(find "$tmp_agent" -type l | sort)
	if [ "$first" = "$second" ] && [ -n "$first" ]; then
		ok "link.sh is idempotent ($(printf '%s\n' "$first" | wc -l) links)"
	else
		bad "link.sh is idempotent" "links changed on second run"
	fi

	# Every link must resolve, and resolve back into this repository.
	dangling=0
	strays=0
	while IFS= read -r link; do
		target=$(readlink -f "$link" 2>/dev/null) || true
		[ -e "$target" ] || dangling=$((dangling + 1))
		case "$target" in "$repo_root"/*) ;; *) strays=$((strays + 1)) ;; esac
	done <<<"$first"
	[ "$dangling" -eq 0 ] && ok "no dangling links" || bad "no dangling links" "$dangling dangling"
	[ ! -L "$tmp_agent/extensions/removed-test-extension.ts" ] && ok "removed tracked resources are unlinked" || bad "removed tracked resources are unlinked"
	[ "$strays" -eq 0 ] && ok "all links point into the repo" || bad "all links point into the repo" "$strays stray"
else
	bad "link.sh runs against a temp agent dir"
fi
rm -rf "$tmp_agent"

# --- unit tests -------------------------------------------------------------

echo
echo "units"
# Extension suites that live beside their code count too; a test file that is
# never collected is the same as no test at all.
unit_files=$(cd "$repo_root" && printf '%s\n' tests/*.test.ts && find "$repo_root/extensions" -name '*.test.ts' -printf '%P\n' | sed 's|^|extensions/|')
if out=$(cd "$repo_root" && node --experimental-strip-types --test $unit_files 2>&1); then
	ok "unit suite ($(printf '%s' "$out" | grep -oP '# pass \K\d+') assertions)"
else
	bad "unit suite" "$out"
fi

# --- pi itself --------------------------------------------------------------

echo
echo "pi"

if ! command -v pi >/dev/null 2>&1; then
	miss "pi loads every extension" "pi not on PATH"
else
	# The single most valuable check: extension load errors go to stderr before
	# any model call, so this catches a broken extension without spending money.
	out=$(cd /tmp && timeout 120 pi --list-models "gpt-5.6-sol" 2>&1)
	if printf '%s' "$out" | grep -qi "Failed to load extension"; then
		bad "pi loads every extension" "$(printf '%s' "$out" | grep -i 'failed to load' | head -3)"
	else
		ok "pi loads every extension"
	fi

	# Loading cannot catch command-time API drift. Invoke /dash through a real
	# RPC process; custom UI is a no-op there, but the command must reach it
	# without emitting an extension error.
	dash=$(cd /tmp && printf '%s\n' '{"id":"dash-check","type":"prompt","message":"/dash"}' |
		timeout 30 pi --mode rpc --no-session 2>&1)
	if printf '%s' "$dash" | grep -q '"id":"dash-check","type":"response","command":"prompt","success":true' &&
		! printf '%s' "$dash" | grep -q '"type":"extension_error"'; then
		ok "/dash command reaches its renderer"
	else
		bad "/dash command reaches its renderer" "$(printf '%s' "$dash" | grep -E 'extension_error|dash-check' | tail -5)"
	fi

	# The removed custom provider must not come back through a stale installed
	# extension. Built-in catalogues may still contain vendor models; the tracked
	# integration was the distinct claude-code provider.
	models=$(cd /tmp && timeout 120 pi --list-models claude 2>&1)
	if printf '%s' "$models" | grep -q 'claude-code'; then
		bad "custom Claude provider is absent" "$models"
	else
		ok "custom Claude provider is absent"
	fi

	# Every provider the config routes to should be authenticated.
	for provider in openai-codex; do
		if timeout 60 pi auth check --provider "$provider" 2>&1 | grep -q ready; then
			ok "provider ready: $provider"
		else
			bad "provider ready: $provider"
		fi
	done
fi

# --- language server binaries ----------------------------------------------

echo
echo "lsp"
if command -v gopls >/dev/null 2>&1 && timeout 15 gopls version >/dev/null 2>&1; then
	ok "gopls is runnable"
else
	bad "gopls is runnable"
fi
if command -v tsgo >/dev/null 2>&1 && timeout 15 tsgo --version >/dev/null 2>&1; then
	ok "tsgo is runnable"
else
	bad "tsgo is runnable"
fi

# --- paid: real turns -------------------------------------------------------

echo
echo "paid"
if [ "$paid" -eq 0 ]; then
	miss "real turn through the default model" "pass --paid to run"
else
	out=$(cd /tmp && timeout 300 pi -p --no-session --thinking off -nt "Reply with exactly: ok" 2>&1)
	if printf '%s' "$out" | grep -qx "ok"; then
		ok "real turn through the default model"
	else
		bad "real turn through the default model" "$out"
	fi
fi

echo
printf 'e2e: %d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
