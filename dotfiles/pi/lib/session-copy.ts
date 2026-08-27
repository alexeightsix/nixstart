export const FORK_DRAFT_ENTRY = "tmux-fork-draft";

export function copySessionName(name: string | undefined, fallbackId: string): string {
	return `Copy of ${name?.trim() || fallbackId.slice(0, 8)}`;
}

export function connectedMcpSummary(names: string[], limit = 3): string | undefined {
	const unique = [...new Set(names.filter((name) => name.trim()).map((name) => name.trim()))];
	if (unique.length === 0) return undefined;
	const shown = unique.slice(0, limit);
	const remaining = unique.length - shown.length;
	return remaining > 0 ? `${shown.join(" ")} +${remaining} others` : shown.join(" ");
}

export function tmuxSplitArgs(
	originPane: string,
	cwd: string,
	sessionFile: string,
	name: string,
	prompt?: string,
): string[] {
	const args = [
		"split-window",
		"-h",
		"-d",
		"-t",
		originPane,
		"-c",
		cwd,
		"-P",
		"-F",
		"#{pane_id}",
		"pi",
		"--session",
		sessionFile,
		"--name",
		name,
	];
	if (prompt) args.push(prompt);
	return args;
}
