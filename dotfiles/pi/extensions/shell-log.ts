/**
 * A per-session log of every `!` shell command.
 *
 * Pi already runs `!command` for you and already feeds the result into the
 * model's context (`!!command` opts out of that). What it does not do is keep a
 * record. This writes one, scoped to the current session: a new file per
 * session, so the log matches the conversation it belongs to.
 *
 *   /shell-log         print this session's commands
 *   /shell-log path    where the file is
 *
 * See docs/shell-log.md — it is the source of truth for this file.
 */

import * as fs from "node:fs";
import * as path from "node:path";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? path.join(process.env.HOME ?? "", ".pi/agent");
}

export default function (pi: ExtensionAPI) {
	let logFile: string | undefined;
	let count = 0;

	// Fires on startup and again on every resume/new/fork, so switching sessions
	// starts a fresh log rather than appending to the previous conversation's.
	pi.on("session_start", async (event) => {
		const dir = path.join(agentDir(), "shell-log");
		fs.mkdirSync(dir, { recursive: true });

		const stamp = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
		logFile = path.join(dir, `${stamp}_${event.reason}.log`);
		count = 0;
	});

	pi.on("user_bash", async (event) => {
		if (!logFile) return undefined;

		const stamp = new Date().toISOString().replace("T", " ").slice(0, 19);
		// `!!` means the user deliberately kept it out of the model's context;
		// record that, because it explains a gap in what the model knows.
		const scope = event.excludeFromContext ? " [hidden from model]" : "";
		fs.appendFileSync(logFile, `${stamp}  ${event.cwd}${scope}\n$ ${event.command}\n`, "utf-8");
		count += 1;

		// Not handled here — let pi run it as usual.
		return undefined;
	});

	pi.registerCommand("shell-log", {
		description: "This session's ! commands (add 'path' for the file location)",
		handler: async (args, ctx) => {
			if (!logFile) {
				ctx.ui.notify("No session log yet.", "warning");
				return;
			}
			if (args.trim() === "path") {
				ctx.ui.notify(logFile, "info");
				return;
			}
			ctx.ui.notify(
				count === 0
					? `No ! commands this session.\n${logFile}`
					: fs.readFileSync(logFile, "utf-8").slice(-8000),
				"info",
			);
		},
	});
}
