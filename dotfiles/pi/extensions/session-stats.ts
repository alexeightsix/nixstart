/**
 * /stats — an analytical breakdown of the session.
 *
 * Where the [statusline] shows the running totals, this shows the composition:
 * which models did the work, what each one cost, how the time was spent, and
 * which tools were called.
 *
 * Everything is derived from the session itself plus events observed as they
 * happen, so it is accurate for the current branch of the conversation.
 *
 * See docs/stats.md — it is the source of truth for this file.
 */

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { type Focusable, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import {
	COST_TIMING_ENTRY,
	type CostTimingRecord,
	formatCostTokens,
	formatStepDuration,
	modelTimingKey,
	projectCostHistory,
	toolTimingKey,
} from "../lib/cost-history.ts";

interface ModelTally {
	turns: number;
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	cost: number;
}

function fmtTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
	if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
	return `${n}`;
}

function fmtDuration(ms: number): string {
	const total = Math.max(0, Math.floor(ms / 1000));
	const h = Math.floor(total / 3600);
	const m = Math.floor((total % 3600) / 60);
	const s = total % 60;
	if (h > 0) return `${h}h ${m}m`;
	if (m > 0) return `${m}m ${s}s`;
	return `${s}s`;
}

function pad(text: string, width: number): string {
	return text.length >= width ? text : text + " ".repeat(width - text.length);
}

function clock(timestamp: number): string {
	const date = new Date(timestamp);
	return [date.getHours(), date.getMinutes(), date.getSeconds()]
		.map((part) => String(part).padStart(2, "0"))
		.join(":");
}

/** Read-only scrollable cost timeline. */
class CostHistoryComponent implements Focusable {
	focused = false;
	private offset = 0;

	constructor(
		private readonly lines: string[],
		private readonly theme: Theme,
		private readonly done: (result: undefined) => void,
	) {}

	handleInput(data: string): void {
		if (matchesKey(data, "escape") || matchesKey(data, "return") || data === "q") {
			this.done(undefined);
			return;
		}
		if (matchesKey(data, "down")) this.offset = Math.min(this.maxOffset(), this.offset + 1);
		else if (matchesKey(data, "up")) this.offset = Math.max(0, this.offset - 1);
		else if (matchesKey(data, "pageDown")) this.offset = Math.min(this.maxOffset(), this.offset + 10);
		else if (matchesKey(data, "pageUp")) this.offset = Math.max(0, this.offset - 10);
	}

	private visibleCount(): number {
		return 28;
	}

	private maxOffset(): number {
		return Math.max(0, this.lines.length - this.visibleCount());
	}

	render(width: number): string[] {
		const inner = Math.max(20, Math.min(width, 100) - 2);
		const row = (content: string) => {
			const clipped = truncateToWidth(content, inner);
			return (
				this.theme.fg("border", "│") +
				clipped +
				" ".repeat(Math.max(0, inner - visibleWidth(clipped))) +
				this.theme.fg("border", "│")
			);
		};
		const window = this.lines.slice(this.offset, this.offset + this.visibleCount());
		return [
			this.theme.fg("border", `╭${"─".repeat(inner)}╮`),
			row(` ${this.theme.fg("accent", "session cost + time")}`),
			this.theme.fg("border", `├${"─".repeat(inner)}┤`),
			...window.map(row),
			this.theme.fg("border", `├${"─".repeat(inner)}┤`),
			row(
				this.theme.fg(
					"dim",
					`  esc close${this.maxOffset() > 0 ? `  ${this.offset + 1}-${this.offset + window.length} of ${this.lines.length}  ↑↓ scroll` : ""}`,
				),
			),
			this.theme.fg("border", `╰${"─".repeat(inner)}╯`),
		];
	}
}

export default function (pi: ExtensionAPI) {
	let sessionStart = Date.now();
	let turnStart: number | null = null;
	const modelStepStarts = new Map<string, number>();
	const toolStepStarts = new Map<string, number>();
	let pendingTimingRecords: CostTimingRecord[] = [];

	/** Wall-clock time actually spent inside turns, as opposed to sitting idle. */
	let workingMs = 0;
	let turns = 0;

	const toolCalls = new Map<string, number>();
	/** Compaction is lossy; how often it has happened is worth surfacing. */
	let compactions = 0;

	pi.on("session_start", async () => {
		sessionStart = Date.now();
		workingMs = 0;
		turns = 0;
		toolCalls.clear();
		compactions = 0;
		modelStepStarts.clear();
		toolStepStarts.clear();
		pendingTimingRecords = [];
	});

	pi.on("session_compact", async () => {
		compactions += 1;
	});

	pi.on("turn_start", async () => {
		turnStart = Date.now();
		turns += 1;
	});

	pi.on("turn_end", async () => {
		if (turnStart !== null) workingMs += Date.now() - turnStart;
		turnStart = null;
		if (pendingTimingRecords.length > 0) {
			pi.appendEntry(COST_TIMING_ENTRY, { records: pendingTimingRecords });
			pendingTimingRecords = [];
		}
	});

	pi.on("message_start", async (event) => {
		if (event.message.role !== "assistant") return;
		modelStepStarts.set(modelTimingKey(event.message as AssistantMessage), Date.now());
	});

	pi.on("message_end", async (event) => {
		if (event.message.role !== "assistant") return;
		const key = modelTimingKey(event.message as AssistantMessage);
		const startedAt = modelStepStarts.get(key);
		if (startedAt !== undefined) {
			pendingTimingRecords.push({ key, durationMs: Date.now() - startedAt });
			modelStepStarts.delete(key);
		}
	});

	pi.on("tool_execution_start", async (event) => {
		const name = event.toolName ?? "unknown";
		toolCalls.set(name, (toolCalls.get(name) ?? 0) + 1);
		toolStepStarts.set(event.toolCallId, Date.now());
	});

	pi.on("tool_execution_end", async (event) => {
		const startedAt = toolStepStarts.get(event.toolCallId);
		if (startedAt !== undefined) {
			pendingTimingRecords.push({
				key: toolTimingKey(event.toolCallId),
				durationMs: Date.now() - startedAt,
			});
			toolStepStarts.delete(event.toolCallId);
		}
	});

	pi.registerCommand("costs", {
		description: "Chronological token cost and elapsed time for each session step",
		handler: async (_args, ctx) => {
			const steps = projectCostHistory(ctx.sessionManager.getBranch() as never);
			if (steps.length === 0) {
				ctx.ui.notify("No model or tool steps on this branch yet.", "info");
				return;
			}

			const theme = ctx.ui.theme;
			const lines: string[] = [];
			const models = steps.filter((step) => step.kind === "model").length;
			const tools = steps.length - models;
			const total = steps.at(-1)?.cumulativeCost ?? 0;
			lines.push(
				` ${models} model step${models === 1 ? "" : "s"} · ${tools} tool step${tools === 1 ? "" : "s"} · ${theme.fg("syntaxFunction", `$${total.toFixed(4)}`)} total`,
			);
			lines.push("");
			lines.push(theme.fg("dim", "  # time     step                            elapsed tokens                 cost    total"));
			for (const step of steps) {
				const kind = step.kind === "model" ? "model" : step.isError ? "tool!" : "tool";
				const label = pad(`${kind} ${step.label}`.slice(0, 30), 30);
				const duration = formatStepDuration(step).padStart(8);
				const tokens = pad(formatCostTokens(step).slice(0, 22), 22);
				const cost = `$${step.cost.toFixed(4)}`.padStart(7);
				const cumulative = `$${step.cumulativeCost.toFixed(4)}`.padStart(8);
				const labelColor = step.isError ? "error" : step.kind === "model" ? "text" : "muted";
				lines.push(
					`${String(step.index).padStart(3)} ${clock(step.at)} ${theme.fg(labelColor, label)} ${duration} ${tokens} ${theme.fg(step.cost > 0 ? "syntaxFunction" : "dim", cost)} ${theme.fg("dim", cumulative)}`,
				);
			}
			lines.push("");
			lines.push(theme.fg("dim", " ~ duration estimated from historical message timestamps · i input · c cache read · w cache write · o output · r reasoning"));

			await ctx.ui.custom<undefined>(
				(_tui, componentTheme, _keybindings, done) =>
					new CostHistoryComponent(lines, componentTheme, done),
				{ overlay: true, overlayOptions: { anchor: "center", width: 104 } },
			);
		},
	});

	pi.registerCommand("stats", {
		description: "Analytical breakdown of this session",
		handler: async (_args, ctx) => {
			const byModel = new Map<string, ModelTally>();
			let messages = 0;

			for (const entry of ctx.sessionManager.getBranch()) {
				if (entry.type !== "message") continue;
				messages += 1;
				if (entry.message.role !== "assistant") continue;

				const message = entry.message as AssistantMessage;
				const key = `${message.provider}/${message.model}`;
				const tally = byModel.get(key) ?? {
					turns: 0,
					input: 0,
					output: 0,
					cacheRead: 0,
					cacheWrite: 0,
					cost: 0,
				};
				tally.turns += 1;
				tally.input += message.usage.input;
				tally.output += message.usage.output;
				tally.cacheRead += message.usage.cacheRead;
				tally.cacheWrite += message.usage.cacheWrite;
				tally.cost += message.usage.cost.total;
				byModel.set(key, tally);
			}

			const totals = [...byModel.values()].reduce(
				(sum, tally) => ({
					input: sum.input + tally.input + tally.cacheRead + tally.cacheWrite,
					output: sum.output + tally.output,
					cost: sum.cost + tally.cost,
					cacheRead: sum.cacheRead + tally.cacheRead,
				}),
				{ input: 0, output: 0, cost: 0, cacheRead: 0 },
			);

			const elapsed = Date.now() - sessionStart;
			const lines: string[] = [];

			lines.push(`Session  ${fmtDuration(elapsed)} elapsed · ${fmtDuration(workingMs)} working · ${turns} turns · ${messages} messages`);
			lines.push(`Spend    ↑${fmtTokens(totals.input)}  ↓${fmtTokens(totals.output)}  $${totals.cost.toFixed(3)}`);

			if (totals.input > 0) {
				const hitRate = Math.round((totals.cacheRead / totals.input) * 100);
				lines.push(`Cache    ${hitRate}% of input served from cache`);
			}

			const usage = ctx.getContextUsage();
			if (usage && usage.tokens !== null && usage.percent !== null) {
				const compacted =
					compactions > 0 ? ` · compacted ${compactions}×` : "";
				lines.push(
					`Context  ${fmtTokens(usage.tokens)} / ${fmtTokens(usage.contextWindow)} (${Math.round(usage.percent)}%) · ${fmtTokens(usage.contextWindow - usage.tokens)} left${compacted}`,
				);
			}

			if (byModel.size > 0) {
				lines.push("");
				lines.push("By model");
				const width = Math.max(...[...byModel.keys()].map((key) => key.length));
				for (const [key, tally] of [...byModel.entries()].sort((a, b) => b[1].cost - a[1].cost)) {
					const share = totals.cost > 0 ? Math.round((tally.cost / totals.cost) * 100) : 0;
					lines.push(
						`  ${pad(key, width)}  ${String(tally.turns).padStart(3)} turns  ↑${fmtTokens(tally.input + tally.cacheRead + tally.cacheWrite)}  ↓${fmtTokens(tally.output)}  $${tally.cost.toFixed(3)}  ${share}%`,
					);
				}
			}

			if (toolCalls.size > 0) {
				lines.push("");
				lines.push("Tools");
				const width = Math.max(...[...toolCalls.keys()].map((key) => key.length));
				for (const [name, count] of [...toolCalls.entries()].sort((a, b) => b[1] - a[1])) {
					lines.push(`  ${pad(name, width)}  ${count}`);
				}
			}

			ctx.ui.notify(lines.join("\n"), "info");
		},
	});
}
