/**
 * Deciding whether a shell command can change anything.
 *
 * Dependency-free on purpose: this is the highest-consequence logic in the
 * config — a false "read-only" silently skips the permission prompt — so it
 * lives where it can be unit-tested without a pi process. See tests/unit.test.ts.
 *
 * The bar is deliberately high: a command is read-only only when *every* segment
 * of it is recognisably read-only. Anything unrecognised is treated as mutating.
 */

/** Commands that cannot change anything outside their own stdout. */
const READ_ONLY_COMMANDS = new Set([
	"awk", "basename", "bat", "cat", "cksum", "column", "comm", "cmp", "cut", "date", "df",
	"diff", "dirname", "du", "echo", "env", "eza", "fd", "file", "find", "free", "grep",
	"head", "hostname", "id", "jq", "less", "ls", "lsof", "man", "md5sum", "nl", "od",
	"pgrep", "ping", "printenv", "printf", "ps", "pwd", "readlink", "realpath", "rg",
	"sha1sum", "sha256sum", "sort", "stat", "tail", "tldr", "tr", "tree", "true", "type",
	"uname", "uniq", "uptime", "wc", "which", "whoami", "xxd", "yq",
]);

/** Subcommands that only report. Anything else under these binaries mutates. */
const READ_ONLY_SUBCOMMANDS: Record<string, Set<string>> = {
	git: new Set([
		"blame", "branch", "config", "describe", "diff", "grep", "log", "ls-files",
		"ls-remote", "ls-tree", "remote", "rev-list", "rev-parse", "shortlog", "show",
		"show-ref", "status", "tag", "whatchanged", "worktree",
	]),
	gh: new Set(["api", "browse", "issue", "pr", "release", "repo", "run", "search", "status"]),
	docker: new Set(["images", "inspect", "logs", "ps", "stats", "top", "version"]),
	kubectl: new Set(["describe", "explain", "get", "logs", "top", "version"]),
	npm: new Set(["explain", "list", "ls", "outdated", "ping", "view", "why"]),
	pnpm: new Set(["list", "ls", "outdated", "why"]),
	cargo: new Set(["metadata", "tree", "--version"]),
	go: new Set(["env", "list", "version", "vet"]),
	terraform: new Set(["output", "plan", "show", "state", "validate", "version"]),
};

/** `gh pr create` mutates even though `gh pr` is on the read-only list. */
const MUTATING_SUBSUBCOMMANDS =
	/^(gh|git)\s+\S+\s+(create|edit|merge|close|delete|comment|review|ready|reopen|add|set|rename|remove|prune)\b/;

export function splitSegments(command: string): string[] {
	// Approximate shell parsing: split on separators that start a new command.
	// Over-splitting is safe here — every segment has to clear the same bar.
	return command
		.split(/(?:\|\||&&|[;\n|])/)
		.map((segment) => segment.trim())
		.filter(Boolean);
}

export function segmentIsReadOnly(segment: string): boolean {
	// Any redirection that is not a discard can create or truncate a file.
	const redirects = segment.match(/\d?>>?\s*\S+/g) ?? [];
	if (redirects.some((redirect) => !/\/dev\/null\s*$/.test(redirect))) return false;

	if (MUTATING_SUBSUBCOMMANDS.test(segment)) return false;

	// Drop leading VAR=value assignments and common wrappers.
	const words = segment.split(/\s+/).filter((word) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(word));
	let index = 0;
	while (words[index] && ["command", "builtin", "nice", "time", "\\"].includes(words[index])) index++;

	const binary = (words[index] ?? "").replace(/^.*\//, "");
	if (!binary) return false;
	if (binary === "sudo" || binary === "doas") return false;
	if (READ_ONLY_COMMANDS.has(binary)) return true;

	const subcommands = READ_ONLY_SUBCOMMANDS[binary];
	if (!subcommands) return false;

	// Skip global flags to find the actual subcommand (`git -C dir status`).
	let cursor = index + 1;
	while (words[cursor]?.startsWith("-") && !subcommands.has(words[cursor])) cursor += 2;
	return subcommands.has(words[cursor] ?? "");
}

export function bashIsReadOnly(command: string): boolean {
	const segments = splitSegments(command);
	return segments.length > 0 && segments.every(segmentIsReadOnly);
}
