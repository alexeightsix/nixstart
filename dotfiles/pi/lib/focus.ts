/**
 * Is the user actually looking at this pi session?
 *
 * Three things must all be true: the terminal window has X focus, the tmux
 * window is the visible one, and our pane is the active pane. Any one of them
 * false means the session is on screen somewhere the user is not looking, which
 * is exactly when a prompt needs a toast.
 *
 * The pid-ancestry walk is separated out and pure so it can be tested; the rest
 * shells out and degrades to "assume visible" when a tool is missing, because
 * a missed toast is better than a storm of false ones.
 *
 * See tests/unit.test.ts.
 */

import { execFileSync } from "node:child_process";

export type PidMap = Map<number, number>;

/**
 * Whether `ancestor` appears in the parent chain of any pid in `from`.
 *
 * A terminal running tmux is the grandparent of the tmux client: the client's
 * parent is the shell, whose parent is the terminal. Walking the chain is what
 * connects "this X window has focus" to "that is my terminal".
 */
export function hasAncestor(pids: PidMap, ancestor: number, from: number[]): boolean {
	for (const start of from) {
		let current: number | undefined = start;
		// Bounded: a corrupt map must not spin forever.
		for (let depth = 0; depth < 32 && current !== undefined && current > 1; depth++) {
			if (current === ancestor) return true;
			current = pids.get(current);
		}
	}
	return false;
}

function run(command: string, args: string[]): string {
	try {
		return execFileSync(command, args, {
			encoding: "utf-8",
			stdio: ["ignore", "pipe", "ignore"],
			timeout: 2000,
		}).trim();
	} catch {
		return "";
	}
}

/** PID of the process owning the focused X window, or undefined. */
export function focusedWindowPid(): number | undefined {
	const active = run("xprop", ["-root", "-notype", "_NET_ACTIVE_WINDOW"]).split(/\s+/).pop();
	if (!active || !active.startsWith("0x")) return undefined;

	const pid = run("xprop", ["-id", active, "-notype", "_NET_WM_PID"]).split(/\s+/).pop();
	const parsed = Number(pid);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : undefined;
}

/** pid -> ppid for every process, for the ancestry walk. */
export function processParents(): PidMap {
	const map: PidMap = new Map();
	for (const line of run("ps", ["-eo", "pid=,ppid="]).split("\n")) {
		const [pid, ppid] = line.trim().split(/\s+/).map(Number);
		if (Number.isFinite(pid) && Number.isFinite(ppid)) map.set(pid, ppid);
	}
	return map;
}

export interface Visibility {
	visible: boolean;
	/** Why not, for the toast body. */
	reason?: "no-client" | "other-tmux-window" | "other-pane" | "unfocused";
	/** Where the session is, so the toast can say where to look. */
	where?: string;
}

/**
 * Whether the pane this pi runs in is on the user's screen right now.
 *
 * Returns visible when detection is impossible (not in tmux, no X, tools
 * missing) — silence is the safer default for a notifier.
 */
export function paneVisible(): Visibility {
	const pane = process.env.TMUX_PANE;
	if (!process.env.TMUX || !pane) return { visible: true };

	const info = run("tmux", [
		"display-message",
		"-p",
		"-t",
		pane,
		"#{client_tty}\t#{window_active}\t#{pane_active}\t#{session_name}:#{window_index}.#{pane_index}\t#{window_name}",
	]);
	if (!info) return { visible: true };

	const [tty, windowActive, paneActive, target, windowName] = info.split("\t");
	const where = `${target}${windowName ? ` (${windowName})` : ""}`;

	// No attached client: the session is running detached, so nobody sees it.
	if (!tty) return { visible: false, reason: "no-client", where };
	if (windowActive !== "1") return { visible: false, reason: "other-tmux-window", where };
	if (paneActive !== "1") return { visible: false, reason: "other-pane", where };

	// The tmux side says visible; now check the terminal actually has focus.
	const activePid = focusedWindowPid();
	if (activePid === undefined) return { visible: true };

	const device = tty.replace(/^\/dev\//, "");
	const onTty = run("ps", ["-o", "pid=", "-t", device])
		.split("\n")
		.map((line) => Number(line.trim()))
		.filter((pid) => Number.isFinite(pid) && pid > 0);
	if (onTty.length === 0) return { visible: true };

	return hasAncestor(processParents(), activePid, onTty)
		? { visible: true }
		: { visible: false, reason: "unfocused", where };
}
