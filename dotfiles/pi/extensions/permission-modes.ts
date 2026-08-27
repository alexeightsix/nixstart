/**
 * Permission Modes
 *
 * Tool permission gating for pi.
 *
 *   all        every tool runs unattended
 *   ask        writes and mutating shell commands ask first (default)
 *   read-only  writes and mutating shell commands are refused
 *
 * Read-only work (read, grep, glob, ls, `git status`, `rg`, …) never prompts in
 * any mode — the gate only fires on things that can change the machine.
 *
 * On top of the mode there are **grants**: paths you have already approved for
 * the rest of the session. A write inside a granted path does not prompt again.
 * Grants are applied immediately — unlike Pi's own `/trust`, nothing restarts.
 *
 *   /perm [all|ask|read-only]   show or set the mode
 *   /grant [path]               approve a path subtree (defaults to cwd)
 *   /grant list                 show what is currently granted
 *   /revoke [path]              withdraw a grant, or all of them
 *   Ctrl+Alt+A                  cycle modes
 *   pi --perm all               start a run in a given mode
 *
 * Grants never confine anything — they only remove prompts. Nothing here
 * restricts which paths a tool may reach.
 *
 * See docs/modes.md — it is the source of truth for this file.
 */

import * as path from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { bashIsReadOnly } from "../lib/bash-classify.ts";
import { permissionIndicator } from "../lib/statusline-model.ts";

type Mode = "all" | "ask" | "read-only";

const MODES: Mode[] = ["all", "ask", "read-only"];
const DEFAULT_MODE: Mode = "ask";

const WRITE_TOOLS = new Set(["edit", "write", "multi_edit", "notebook_edit"]);

/** Shorten a path for display: `~/dev/spotlight`, or `/` unchanged. */
function displayPath(target: string): string {
	const home = process.env.HOME;
	if (home && target === home) return "~";
	if (home && target.startsWith(`${home}/`)) return `~/${target.slice(home.length + 1)}`;
	return target;
}

export default function (pi: ExtensionAPI) {
	let mode: Mode = DEFAULT_MODE;
	const grants = new Set<string>();

	pi.registerFlag("perm", {
		description: `Permission mode: ${MODES.join(", ")} (default: ${DEFAULT_MODE})`,
		type: "string",
	});

	/** How far the current grants reach, for display. */
	const grantScope = (): string => {
		if (grants.size === 0) return "none";
		if (grants.has("/")) return "/ (everything)";
		const roots = [...grants].sort((a, b) => a.length - b.length);
		const shallowest = roots.filter(
			(candidate) => !roots.some((other) => other !== candidate && candidate.startsWith(`${other}/`)),
		);
		return shallowest.length === 1
			? displayPath(shallowest[0])
			: `${displayPath(shallowest[0])} +${shallowest.length - 1}`;
	};

	const isGranted = (target: string | undefined): boolean => {
		if (!target) return false;
		const absolute = path.resolve(target);
		for (const granted of grants) {
			if (granted === "/" || absolute === granted || absolute.startsWith(`${granted}/`)) return true;
		}
		return false;
	};

	const showStatus = (ctx: ExtensionContext) => {
		const theme = ctx.ui.theme;
		// A coloured dot plus one punctuation mark stays compact but makes the
		// state decipherable: ! = all, ? = ask, – = read-only.
		const color = mode === "all" ? "error" : mode === "ask" ? "warning" : "success";
		const scope = grants.size > 0 ? theme.fg("dim", `+${grantScope()}`) : "";
		ctx.ui.setStatus("permission-mode", theme.fg(color, permissionIndicator(mode)) + scope);
	};

	const setMode = (next: Mode, ctx: ExtensionContext) => {
		mode = next;
		showStatus(ctx);
	};

	// Also fires on resume/new/fork. Grants are dropped there on purpose: an
	// approval given in one conversation should not silently cover the next.
	pi.on("session_start", async (event, ctx) => {
		if (event.reason !== "startup") grants.clear();
		const flag = pi.getFlag("perm");
		if (typeof flag === "string" && MODES.includes(flag as Mode)) mode = flag as Mode;
		showStatus(ctx);
	});

	pi.registerCommand("perm", {
		description: `Permission mode (${MODES.join(" | ")})`,
		handler: async (args, ctx) => {
			const requested = args.trim();
			if (!requested) {
				const choice = await ctx.ui.select(`Permission mode (now: ${mode})`, MODES);
				if (choice) setMode(choice as Mode, ctx);
				return;
			}
			if (!MODES.includes(requested as Mode)) {
				ctx.ui.notify(`Unknown mode "${requested}". Use: ${MODES.join(", ")}`, "error");
				return;
			}
			setMode(requested as Mode, ctx);
			ctx.ui.notify(`Permission mode: ${mode}`, "info");
		},
	});

	pi.registerCommand("grant", {
		description: "Approve a path subtree for this session, no restart (defaults to cwd)",
		handler: async (args, ctx) => {
			const requested = args.trim();

			if (requested === "list") {
				ctx.ui.notify(
					grants.size === 0
						? `No grants. Working directory: ${displayPath(ctx.cwd)}`
						: [`Working directory: ${displayPath(ctx.cwd)}`, "Granted:", ...[...grants].map((g) => `  ${displayPath(g)}`)].join("\n"),
					"info",
				);
				return;
			}

			const target = requested ? path.resolve(ctx.cwd, requested) : ctx.cwd;
			grants.add(target);
			showStatus(ctx);
			ctx.ui.notify(
				`Granted ${displayPath(target)} for this session. Writes below it will not prompt.`,
				"info",
			);
		},
	});

	pi.registerCommand("revoke", {
		description: "Withdraw a path grant, or all of them",
		handler: async (args, ctx) => {
			const requested = args.trim();
			if (!requested || requested === "all") {
				grants.clear();
				showStatus(ctx);
				ctx.ui.notify("All grants withdrawn.", "info");
				return;
			}
			const target = path.resolve(ctx.cwd, requested);
			ctx.ui.notify(
				grants.delete(target)
					? `Withdrew ${displayPath(target)}.`
					: `${displayPath(target)} was not granted.`,
				"info",
			);
			showStatus(ctx);
		},
	});

	pi.registerShortcut("ctrl+alt+a", {
		description: "Cycle permission mode",
		handler: (ctx) => {
			setMode(MODES[(MODES.indexOf(mode) + 1) % MODES.length], ctx);
			ctx.ui.notify(`Permission mode: ${mode}`, "info");
		},
	});

	pi.on("tool_call", async (event, ctx) => {
		if (mode === "all") return undefined;

		let what: string | undefined;
		let target: string | undefined;

		if (WRITE_TOOLS.has(event.toolName)) {
			const input = event.input as { path?: string; file_path?: string };
			target = input.path ?? input.file_path;
			what = `${event.toolName}: ${target ?? ""}`;
		} else if (event.toolName === "bash") {
			const command = String((event.input as { command?: string }).command ?? "");
			if (bashIsReadOnly(command)) return undefined;
			target = ctx.cwd;
			what = `bash: ${command}`;
		} else {
			return undefined;
		}

		if (mode === "read-only") {
			return {
				block: true,
				reason: `Blocked: permission mode is read-only (${event.toolName}). Ask the user to switch modes with /perm.`,
			};
		}

		// Already approved this subtree earlier in the session.
		if (isGranted(target)) return undefined;

		if (!ctx.hasUI) {
			return { block: true, reason: "Blocked: permission mode is ask and there is no UI to confirm with." };
		}

		const folder = target ? path.dirname(path.resolve(target)) : ctx.cwd;

		// This is the prompt worth a toast: it blocks the agent mid-turn, which
		// is precisely when you have switched away to do something else.
		// notify.ts decides whether you can actually see it.
		pi.events.emit("notify:attention", {
			title: "pi needs permission",
			body: what,
			urgency: "critical",
			kind: "permission",
		});

		const choice = await ctx.ui.select(`Allow?\n\n  ${what}`, [
			"Allow once",
			`Allow everything under ${displayPath(folder)}`,
			"Allow all this session",
			"Deny",
		]);

		if (choice?.startsWith("Allow everything under")) {
			grants.add(folder);
			showStatus(ctx);
			return undefined;
		}
		if (choice === "Allow all this session") {
			setMode("all", ctx);
			return undefined;
		}
		if (choice !== "Allow once") {
			return { block: true, reason: "Denied by user." };
		}
		return undefined;
	});
}
