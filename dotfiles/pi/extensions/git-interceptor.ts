/**
 * Git Interceptor
 *
 * Three guards for agent-driven git commands:
 *
 * 1. Editor hang prevention — Sets GIT_EDITOR, GIT_SEQUENCE_EDITOR to `true`
 *    (no-op) and GIT_MERGE_AUTOEDIT to `no` so git never spawns an interactive
 *    editor (nvim, vim, etc.) that would hang the bash process.
 *
 * 2. Hook bypass prevention — Blocks any command containing `--no-verify` so
 *    the agent cannot circumvent git hooks (pre-commit, commit-msg, etc.).
 *
 * 3. Project shipping policy — When the workspace (or an ancestor) contains
 *    ship.sh, blocks direct `git commit` and `git push`. Agents must use the
 *    project script so ticket validation, authorship, commit formatting, and
 *    non-blocking push behavior stay consistent.
 */

import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { directGitShipSubcommand } from "../lib/git-interceptor.ts";

const GIT_ENV_PREFIX =
	"export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";

const NO_VERIFY_RE = /--no-verify\b/;
const NO_VERIFY_BLOCK_REASON =
	"BLOCKED: --no-verify is not allowed. Git hooks exist for a reason. " +
	"Do not attempt to bypass them. Instead: fix the underlying issue that " +
	"is causing the hook to fail, or ask the user for help.";

function findShipScript(cwd: string): string | undefined {
	let directory = cwd;
	while (true) {
		const candidate = join(directory, "ship.sh");
		if (existsSync(candidate)) return candidate;

		const parent = dirname(directory);
		if (parent === directory) return undefined;
		directory = parent;
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;
		if (!event.input.command.includes("git")) return;

		if (NO_VERIFY_RE.test(event.input.command)) {
			return { block: true, reason: NO_VERIFY_BLOCK_REASON };
		}

		const shipScript = findShipScript(ctx.cwd);
		const blockedSubcommand = shipScript
			? directGitShipSubcommand(event.input.command)
			: undefined;
		if (blockedSubcommand) {
			return {
				block: true,
				reason:
					`BLOCKED: direct git ${blockedSubcommand} is disabled in this workspace. ` +
					`Use ${shipScript} DEV-123/name-of-ticket 'commit message' from inside ` +
					"the target repository or submodule.",
			};
		}

		event.input.command = GIT_ENV_PREFIX + event.input.command;
	});
}
