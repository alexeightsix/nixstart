/**
 * /kill and /limit — stop this session running away with your money.
 *
 *   /kill     shut pi down now, or at a time you pick
 *   /limit    cap what this session may spend, then refuse to start new turns
 *
 * The two are deliberately different: a limit stops new work while leaving the
 * session open and everything in it recoverable; a kill ends the process. A
 * limit is the one you want almost always.
 *
 * See docs/guardrails.md — it is the source of truth for this file.
 */

import type { AssistantMessage, ImageContent } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { parseLimit, parseWhen } from "../lib/parse.ts";

interface Limit {
	/** Ceiling in dollars, or null when the cap is on tokens. */
	dollars: number | null;
	tokens: number | null;
	/** Stop new turns, or only warn once. */
	hard: boolean;
	warned: boolean;
	/** Spend before a model handoff; the same allowance restarts after switching. */
	baselineDollars: number;
	baselineTokens: number;
}

function fmtTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
	if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
	return `${n}`;
}

function fmtClock(at: number): string {
	return new Date(at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function fmtLeft(ms: number): string {
	const minutes = Math.max(0, Math.ceil(ms / 60000));
	if (minutes >= 60) return `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, "0")}m`;
	return `${minutes}m`;
}

function handoffInstructions(): string {
	return "Write a redacted handoff document in the OS temporary directory, reference existing artifacts instead of duplicating them, and include suggested skills for the agent taking over.";
}

export default function (pi: ExtensionAPI) {
	let limit: Limit | undefined;
	let killAt: number | undefined;
	let killTimer: ReturnType<typeof setTimeout> | undefined;
	let pauseUntil: number | undefined;
	let pauseTimer: ReturnType<typeof setTimeout> | undefined;
	let countdown: ReturnType<typeof setInterval> | undefined;
	let handoffBypassText: string | undefined;

	// Bound per session: timers outlive the handler their ctx came from.
	let setStatus: ((key: string, value: string | undefined) => void) | undefined;
	let notify: ((message: string, level: "info" | "warning" | "error") => void) | undefined;
	let fg: ((color: string, text: string) => string) | undefined;
	let shutdown: (() => void) | undefined;

	/** Spend so far on the current branch. */
	const spend = (ctx: ExtensionContext) => {
		let tokens = 0;
		let dollars = 0;
		for (const entry of ctx.sessionManager.getBranch()) {
			if (entry.type !== "message" || entry.message.role !== "assistant") continue;
			const message = entry.message as AssistantMessage;
			tokens += message.usage.totalTokens;
			dollars += message.usage.cost.total;
		}
		return { tokens, dollars };
	};

	const overLimit = (ctx: ExtensionContext): string | undefined => {
		if (!limit) return undefined;
		const total = spend(ctx);
		const used = {
			dollars: Math.max(0, total.dollars - limit.baselineDollars),
			tokens: Math.max(0, total.tokens - limit.baselineTokens),
		};
		if (limit.dollars !== null && used.dollars >= limit.dollars) {
			return `$${used.dollars.toFixed(2)} of $${limit.dollars.toFixed(2)}`;
		}
		if (limit.tokens !== null && used.tokens >= limit.tokens) {
			return `${fmtTokens(used.tokens)} of ${fmtTokens(limit.tokens)} tokens`;
		}
		return undefined;
	};

	/** Last known spend, so the status can redraw without an ExtensionContext. */
	let lastSpend = { tokens: 0, dollars: 0 };

	const renderStatus = () => {
		if (!setStatus || !fg) return;
		const parts: string[] = [];

		if (pauseUntil && pauseUntil > Date.now()) {
			parts.push(fg("warning", `pause ${fmtClock(pauseUntil)} (${fmtLeft(pauseUntil - Date.now())})`));
		}

		if (limit) {
			const used = {
				dollars: Math.max(0, lastSpend.dollars - limit.baselineDollars),
				tokens: Math.max(0, lastSpend.tokens - limit.baselineTokens),
			};
			const [now, cap] =
				limit.dollars !== null
					? [`$${used.dollars.toFixed(2)}`, `$${limit.dollars.toFixed(2)}`]
					: [fmtTokens(used.tokens), fmtTokens(limit.tokens ?? 0)];
			const ratio =
				limit.dollars !== null
					? used.dollars / limit.dollars
					: used.tokens / (limit.tokens || 1);
			const color = ratio >= 1 ? "error" : ratio >= 0.8 ? "warning" : "dim";
			parts.push(fg(color, `limit ${now}/${cap}`));
		}

		if (killAt) {
			parts.push(fg("error", `kill ${fmtClock(killAt)} (${fmtLeft(killAt - Date.now())})`));
		}

		setStatus("guardrails", parts.length > 0 ? parts.join("  ") : undefined);
	};

	const showStatus = (ctx: ExtensionContext) => {
		lastSpend = spend(ctx);
		renderStatus();
	};

	const persistPause = () => pi.appendEntry("guardrails-pause", { until: pauseUntil });

	const clearPause = (ctx: ExtensionContext, announce: boolean) => {
		if (pauseTimer) clearTimeout(pauseTimer);
		pauseTimer = undefined;
		pauseUntil = undefined;
		persistPause();
		pi.events.emit("guardrails:pause-changed", { active: false });
		showStatus(ctx);
		if (announce) ctx.ui.notify("Pause lifted — queued work may resume.", "info");
	};

	const schedulePause = (at: number, ctx: ExtensionContext, persist = true) => {
		if (pauseTimer) clearTimeout(pauseTimer);
		pauseUntil = at;
		if (persist) persistPause();
		pi.events.emit("guardrails:pause-changed", { active: true, until: at });
		pauseTimer = setTimeout(
			() => {
				pauseTimer = undefined;
				pauseUntil = undefined;
				persistPause();
				pi.events.emit("guardrails:pause-changed", { active: false });
				renderStatus();
				notify?.("Pause finished — queued work may resume.", "info");
			},
			Math.max(0, at - Date.now()),
		);
		showStatus(ctx);
	};

	const choosePause = async (ctx: ExtensionContext): Promise<number | undefined> => {
		const choice = await ctx.ui.select("Pause future turns for how long?", [
			"5 minutes",
			"15 minutes",
			"1 hour",
			"Custom…",
			"Cancel",
		]);
		if (!choice || choice === "Cancel") return undefined;
		if (choice === "5 minutes") return Date.now() + 5 * 60_000;
		if (choice === "15 minutes") return Date.now() + 15 * 60_000;
		if (choice === "1 hour") return Date.now() + 60 * 60_000;
		const answer = await ctx.ui.input("Pause until? (45m, 2h, or 17:30)", "45m");
		if (!answer) return undefined;
		const at = parseWhen(answer);
		if (!at) ctx.ui.notify(`Could not read "${answer}". Try 45m, 2h, or 17:30.`, "error");
		return at ?? undefined;
	};

	const scheduleKill = (at: number, ctx: ExtensionContext) => {
		if (killTimer) clearTimeout(killTimer);
		killAt = at;
		killTimer = setTimeout(
			() => {
				notify?.("Scheduled kill reached — shutting down.", "error");
				try {
					shutdown?.();
				} catch {
					// Graceful path unavailable; take the process down anyway,
					// which is the entire point of a kill switch.
					process.kill(process.pid, "SIGTERM");
				}
			},
			Math.max(0, at - Date.now()),
		);
		showStatus(ctx);
	};

	pi.on("session_start", async (_event, ctx) => {
		setStatus = ctx.ui.setStatus.bind(ctx.ui);
		notify = ctx.ui.notify.bind(ctx.ui);
		fg = ctx.ui.theme.fg.bind(ctx.ui.theme) as typeof fg;
		shutdown = ctx.shutdown.bind(ctx);

		if (pauseTimer) clearTimeout(pauseTimer);
		pauseTimer = undefined;
		pauseUntil = undefined;
		const pauseEntry = ctx.sessionManager
			.getEntries()
			.filter(
				(entry: { type: string; customType?: string }) =>
					entry.type === "custom" && entry.customType === "guardrails-pause",
			)
			.pop() as { data?: { until?: number } } | undefined;
		if (pauseEntry?.data?.until && pauseEntry.data.until > Date.now()) {
			schedulePause(pauseEntry.data.until, ctx, false);
		} else {
			pi.events.emit("guardrails:pause-changed", { active: false });
			showStatus(ctx);
		}

		// Guardrail countdowns have to tick while the session sits idle.
		if (countdown) clearInterval(countdown);
		countdown = setInterval(() => {
			if (killAt || pauseUntil) renderStatus();
		}, 30_000);
	});

	pi.on("session_shutdown", async () => {
		if (countdown) clearInterval(countdown);
		if (killTimer) clearTimeout(killTimer);
		if (pauseTimer) clearTimeout(pauseTimer);
	});

	// Refresh the readout as spend accumulates, and warn as the cap approaches.
	pi.on("turn_end", async (_event, ctx) => {
		showStatus(ctx);
		if (!limit || limit.warned) return;
		const breached = overLimit(ctx);
		if (breached) {
			limit.warned = true;
			ctx.ui.notify(
				limit.hard
					? limit.tokens !== null
						? `Token limit reached: ${breached}. The next prompt can pause, switch model with a handoff, or cancel.`
						: `Limit reached: ${breached}. No new turns will start. /limit off to lift it.`
					: `Limit reached: ${breached}. Warning only — turns continue.`,
				"error",
			);
		}
	});

	pi.on("input", async (event, ctx) => {
		const requested = event.text.trimStart();
		if (requested.startsWith("/")) return { action: "continue" as const };

		if (handoffBypassText === event.text) {
			handoffBypassText = undefined;
			return { action: "continue" as const };
		}

		if (pauseUntil && pauseUntil > Date.now()) {
			// Steering belongs to the active turn, which a pause deliberately lets finish.
			if (!ctx.isIdle() && event.source !== "extension") return { action: "continue" as const };
			// In the TUI, send-hold owns ordinary prompts and keeps them in its FIFO.
			if (ctx.mode === "tui" && event.source !== "extension") return { action: "continue" as const };
			ctx.ui.notify(`Paused until ${fmtClock(pauseUntil)} (${fmtLeft(pauseUntil - Date.now())}).`, "warning");
			if (event.source === "extension") {
				pi.events.emit("guardrails:input-blocked", {
					text: event.text,
					reason: "pause",
				});
			}
			return { action: "handled" as const };
		}

		if (!limit?.hard) return { action: "continue" as const };
		const breached = overLimit(ctx);
		if (!breached) return { action: "continue" as const };

		const restore = (reason: "limit" | "pause") => {
			if (event.source === "extension") {
				pi.events.emit("guardrails:input-blocked", { text: event.text, breached, reason });
			}
		};
		const cancel = () => {
			if (event.source === "extension") {
				pi.events.emit("guardrails:input-cancelled", { text: event.text });
			}
		};

		// Dollar limits and non-interactive clients retain the direct hard block.
		if (limit.tokens === null || ctx.mode !== "tui") {
			ctx.ui.notify(
				`Blocked — this session has spent ${breached}. Raise it with /limit, or lift it with /limit off.`,
				"error",
			);
			restore("limit");
			return { action: "handled" as const };
		}

		const decision = await ctx.ui.select(`Token limit reached: ${breached}`, [
			"Pause and retry later",
			"Switch model and continue with a handoff",
			"Cancel this prompt",
		]);

		if (decision === "Pause and retry later") {
			const at = await choosePause(ctx);
			if (!at) {
				cancel();
				return { action: "handled" as const };
			}
			schedulePause(at, ctx);
			restore("pause");
			ctx.ui.notify(`Queued prompt will retry after ${fmtClock(at)}.`, "warning");
			return { action: "handled" as const };
		}

		if (decision === "Switch model and continue with a handoff") {
			const alternatives = ctx.scopedModels.filter(
				(candidate) =>
					candidate.model.id !== ctx.model?.id || candidate.model.provider !== ctx.model?.provider,
			);
			if (alternatives.length === 0) {
				ctx.ui.notify("No alternate scoped model is available. The prompt remains queued.", "error");
				restore("limit");
				return { action: "handled" as const };
			}
			const labels = alternatives.map((candidate) => `${candidate.model.provider}/${candidate.model.id}`);
			const selected = await ctx.ui.select("Continue on which model?", [...labels, "Cancel"]);
			const index = selected ? labels.indexOf(selected) : -1;
			if (index < 0) {
				cancel();
				return { action: "handled" as const };
			}

			const target = alternatives[index].model;
			const switched = await pi.setModel(target);
			if (!switched) {
				restore("limit");
				ctx.ui.notify("The selected model has no usable credentials. The prompt remains queued.", "error");
				return { action: "handled" as const };
			}
			cancel();
			const used = spend(ctx);
			limit.baselineTokens = used.tokens;
			limit.warned = false;
			showStatus(ctx);
			pi.events.emit("guardrails:limit-changed", { active: true, reset: true });

			const takeover = [
				"You are taking over this session because its previous model reached the token allowance.",
				"Before continuing, apply Matt Pocock's handoff workflow below: write the redacted handoff document, then use it and the existing session context to continue the retained request.",
				"",
				handoffInstructions(),
				"",
				"Retained request:",
				event.text,
			].join("\n");
			handoffBypassText = takeover;
			const content: string | ({ type: "text"; text: string } | ImageContent)[] = event.images?.length
				? [{ type: "text", text: takeover }, ...event.images]
				: takeover;
			pi.sendUserMessage(content);
			ctx.ui.notify(
				`Switched to ${target.provider}/${target.id}; token allowance restarted and the retained prompt was handed over.`,
				"info",
			);
			return { action: "handled" as const };
		}

		cancel();
		return { action: "handled" as const };
	});

	pi.registerCommand("pause", {
		description: "Pause future turns for a preset or custom duration — 'off' to resume",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();
			if (requested === "off" || requested === "cancel" || requested === "none") {
				if (!pauseUntil) {
					ctx.ui.notify("No pause is active.", "info");
					return;
				}
				clearPause(ctx, true);
				return;
			}

			const at = requested ? parseWhen(requested) : await choosePause(ctx);
			if (!at) {
				if (requested) ctx.ui.notify(`Could not read "${requested}". Try 45m, 2h, or 17:30.`, "error");
				return;
			}
			schedulePause(at, ctx);
			ctx.ui.notify(
				`Future turns paused until ${fmtClock(at)} (for ${fmtLeft(at - Date.now())}). The active turn may finish.`,
				"warning",
			);
		},
	});

	pi.registerCommand("kill", {
		description: "Shut pi down now, or at a scheduled time",
		handler: async (args, ctx) => {
			const requested = args.trim();

			if (requested === "cancel") {
				if (killTimer) clearTimeout(killTimer);
				killTimer = undefined;
				killAt = undefined;
				showStatus(ctx);
				ctx.ui.notify("Scheduled kill cancelled.", "info");
				return;
			}

			// An argument is a time; no argument asks.
			if (requested) {
				const at = parseWhen(requested);
				if (!at) {
					ctx.ui.notify(`Could not read "${requested}". Try 45m, 2h, or 17:30.`, "error");
					return;
				}
				scheduleKill(at, ctx);
				ctx.ui.notify(`Pi will shut down at ${fmtClock(at)} (in ${fmtLeft(at - Date.now())}).`, "warning");
				return;
			}

			const when = await ctx.ui.select("Kill pi when?", [
				"Now — shut down immediately",
				"Scheduled — at a time I choose",
				killAt ? "Cancel the scheduled kill" : "Never mind",
			]);
			if (!when || when === "Never mind") return;

			if (when.startsWith("Cancel")) {
				if (killTimer) clearTimeout(killTimer);
				killTimer = undefined;
				killAt = undefined;
				showStatus(ctx);
				ctx.ui.notify("Scheduled kill cancelled.", "info");
				return;
			}

			if (when.startsWith("Now")) {
				const sure = await ctx.ui.confirm(
					"Shut down pi now?",
					"The session is saved and can be resumed. Work in progress is lost.",
				);
				if (!sure) return;
				ctx.shutdown();
				return;
			}

			const answer = await ctx.ui.input("Kill at? (45m, 2h, or 17:30)", "45m");
			if (!answer) return;
			const at = parseWhen(answer);
			if (!at) {
				ctx.ui.notify(`Could not read "${answer}". Try 45m, 2h, or 17:30.`, "error");
				return;
			}
			scheduleKill(at, ctx);
			ctx.ui.notify(`Pi will shut down at ${fmtClock(at)} (in ${fmtLeft(at - Date.now())}).`, "warning");
		},
	});

	pi.registerCommand("limit", {
		description: "Cap this session's spend ($5, 500k) — 'off' to lift, 'warn' for warn-only",
		handler: async (args, ctx) => {
			const requested = args.trim().toLowerCase();

			if (requested === "off" || requested === "none") {
				limit = undefined;
				showStatus(ctx);
				pi.events.emit("guardrails:limit-changed", { active: false });
				ctx.ui.notify("Spend limit lifted.", "info");
				return;
			}

			if (!requested) {
				const used = spend(ctx);
				ctx.ui.notify(
					limit
						? `Spent $${used.dollars.toFixed(3)} / ${fmtTokens(used.tokens)} tokens. Limit: ${
								limit.dollars !== null ? `$${limit.dollars.toFixed(2)}` : `${fmtTokens(limit.tokens ?? 0)} tokens`
							} (${limit.hard ? "blocks new turns" : "warns only"}).`
						: `Spent $${used.dollars.toFixed(3)} / ${fmtTokens(used.tokens)} tokens. No limit set — /limit $5 or /limit 500k.`,
					"info",
				);
				return;
			}

			const warnOnly = requested.startsWith("warn");
			const value = warnOnly ? requested.replace(/^warn\s*/, "") : requested;
			const parsed = parseLimit(value);
			if (!parsed) {
				ctx.ui.notify(`Could not read "${value}". Try $5, 500k, or 2M.`, "error");
				return;
			}

			limit = {
				...parsed,
				hard: !warnOnly,
				warned: false,
				baselineDollars: 0,
				baselineTokens: 0,
			};
			showStatus(ctx);
			pi.events.emit("guardrails:limit-changed", { active: limit.hard });
			ctx.ui.notify(
				`Limit set: ${
					parsed.dollars !== null ? `$${parsed.dollars.toFixed(2)}` : `${fmtTokens(parsed.tokens ?? 0)} tokens`
				}. ${warnOnly ? "Warns only." : "New turns are blocked once reached."}`,
				"info",
			);
		},
	});
}
