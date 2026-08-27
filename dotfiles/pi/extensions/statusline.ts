/**
 * Statusline
 *
 * Replaces pi's built-in footer with a single line:
 *
 *   INSERT  ●?  5.6-sol  ◇high  linear fathom     ↑ 12k ↓ 3.4k  ↺ 71%  $ 0.18  ◫ 18%/272k 223k left
 *
 * Left  — active operational state and connected MCP names.
 * Right — one stable, right-aligned usage and spend block.
 *
 * Everything is one line. When the terminal is too narrow, optional left-side
 * state truncates before the right-side usage figures.
 */

// @ts-ignore -- Pi supplies these runtime modules to global extensions.
import type { AssistantMessage } from "@earendil-works/pi-ai";
// @ts-ignore -- Node is available to global extensions at runtime.
import { execFile } from "node:child_process";
// @ts-ignore -- Pi supplies these runtime modules to global extensions.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
// @ts-ignore -- Pi supplies these runtime modules to global extensions.
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import { burnAliasForPiProvider, burnStatusesFromJson, formatBurnStatus, type BurnStatus } from "../lib/burn-status.ts";
import { formatUsageIcon, leftExtensionStatuses, STATUS_ICONS } from "../lib/statusline-layout.ts";
import { connectedMcpSummary } from "../lib/session-copy.ts";
import {
	addRecentSkill,
	recentSkillsFromEntries,
	skillNameFromCommand,
	skillNameFromReadPath,
	type SkillHistoryEntry,
} from "../lib/statusline-skills.ts";
import { compactModelName, thinkingIndicator } from "../lib/statusline-model.ts";

const SEP = "  ";
const SKILL_ENTRY_TYPE = "statusline-skill-loaded";

interface StatuslineTheme {
	fg(color: string, value: string): string;
}

interface StatuslineTui {
	requestRender(): void;
}

interface StatuslineFooterData {
	getExtensionStatuses(): ReadonlyMap<string, string>;
	onBranchChange(callback: () => void): () => void;
}

interface McpStatusSnapshot {
	servers?: Array<{ name?: string; status?: string }>;
}

interface StatuslineContext {
	cwd: string;
	getContextUsage():
		| { contextWindow: number; percent: number | null; tokens: number | null }
		| undefined;
	mode: string;
	model?: { id: string; provider?: string };
	sessionManager: {
		getBranch(): Array<{
			message?: { role?: string };
			type: string;
		}>;
	};
	thinkingLevel?: string;
	ui: {
		setFooter(
			factory: (
				tui: StatuslineTui,
				theme: StatuslineTheme,
				footerData: StatuslineFooterData,
			) => {
				dispose(): void;
				invalidate(): void;
				render(width: number): string[];
			},
		): void;
		setWorkingIndicator(options: { frames: string[] }): void;
	};
}

/** Braille spinner: the working indicator, shown only while a turn is live. */
const SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

function capitalize(value: string): string {
	return value.charAt(0).toUpperCase() + value.slice(1);
}

function fmtTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
	if (n >= 10_000) return `${Math.round(n / 1000)}k`;
	if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
	return `${n}`;
}

/**
 * Each model gets its own colour so the active one is recognisable at a glance
 * without reading the name. Known models are pinned by family; anything else is
 * hashed onto the same palette, which keeps a given model's colour stable
 * between sessions.
 */
/* Rose-pine collapses to five usable hues: iris, foam, gold, love, rose. */
const MODEL_PALETTE = ["accent", "success", "warning", "error", "syntaxFunction", "muted"] as const;

const MODEL_COLORS: Record<string, string> = {
	"gpt-5.6-sol": "success",
	"gpt-5.6-terra": "accent",
	"gpt-5.6-luna": "accent",
	"gpt-5.5": "muted",
	"kimi-k3": "error",
	"deepseek-v4-flash": "muted",
};

function modelColor(id: string): string {
	const pinned = MODEL_COLORS[id];
	if (pinned) return pinned;
	let hash = 0;
	for (let index = 0; index < id.length; index++) hash = (hash * 31 + id.charCodeAt(index)) >>> 0;
	return MODEL_PALETTE[hash % MODEL_PALETTE.length];
}

export default function (pi: ExtensionAPI) {
	let turnStart: number | null = null;
	let recentSkills: string[] = [];
	let connectedMcpNames: string[] = [];
	let burnStatuses: BurnStatus[] = [];
	/** /zen hides the line entirely. */
	let hidden = false;
	let requestRender: (() => void) | undefined;

	function recordSkill(name: string): void {
		recentSkills = addRecentSkill(recentSkills, name);
		pi.appendEntry(SKILL_ENTRY_TYPE, { name });
		requestRender?.();
	}

	pi.events.on("pi-mcp-adapter/status/v1", (data: unknown) => {
		const snapshot = data as McpStatusSnapshot;
		connectedMcpNames = (snapshot.servers ?? [])
			.filter((server) => server.status === "connected" && typeof server.name === "string")
			.map((server) => server.name as string);
		requestRender?.();
	});

	pi.registerCommand("zen", {
		description: "Hide or show the statusline",
		handler: (_args: string, ctx: { ui: { notify(message: string, level: string): void } }) => {
			hidden = !hidden;
			requestRender?.();
			ctx.ui.notify(hidden ? "Statusline hidden. /zen to bring it back." : "Statusline back.", "info");
		},
	});

	pi.on("input", (event: { text: string }) => {
		const name = skillNameFromCommand(event.text);
		if (!name) return;
		const command = `skill:${name}`;
		if (
			!pi
				.getCommands()
				.some(
					(candidate: { name: string; source: string }) =>
						candidate.source === "skill" && candidate.name === command,
				)
		)
			return;
		recordSkill(name);
	});

	pi.on(
		"tool_result",
		(event: { input: unknown; isError: boolean; toolName: string }) => {
			if (event.toolName !== "read" || event.isError) return;
			const input = event.input as { path?: unknown };
			if (typeof input.path !== "string") return;
			const name = skillNameFromReadPath(input.path);
			if (name) recordSkill(name);
		},
	);

	pi.on("session_start", (_event: unknown, ctx: StatuslineContext) => {
		turnStart = null;
		connectedMcpNames = [];
		recentSkills = recentSkillsFromEntries(
			ctx.sessionManager.getBranch() as SkillHistoryEntry[],
			SKILL_ENTRY_TYPE,
		);

		// Only the TUI has a footer to replace.
		if (ctx.mode !== "tui") return;

		// The spinner lives in the statusline, so hide Pi's own streaming loader.
		// Two working indicators for one turn is just noise.
		ctx.ui.setWorkingIndicator({ frames: [] });

		ctx.ui.setFooter(
			(tui: StatuslineTui, theme: StatuslineTheme, footerData: StatuslineFooterData) => {
			const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
			requestRender = () => tui.requestRender();
			let disposed = false;
			const refreshBurnStatus = () => {
				execFile("burn", ["--json"], { maxBuffer: 5 * 1024 * 1024 }, (error, stdout) => {
					if (disposed) return;
					burnStatuses = error ? [] : burnStatusesFromJson(stdout);
					tui.requestRender();
				});
			};
			refreshBurnStatus();
			const burnTicker = setInterval(refreshBurnStatus, 60_000);
			// Keep the elapsed timer moving while the agent is working. Idle
			// sessions do not re-render, so this costs nothing between turns.
			// Fast enough for the spinner to read as motion; only runs mid-turn,
			// so an idle session does not re-render at all.
			const ticker = setInterval(() => {
				if (turnStart !== null) tui.requestRender();
			}, 100);

			return {
				dispose() {
					disposed = true;
					unsubscribe();
					clearInterval(ticker);
					clearInterval(burnTicker);
				},
				invalidate() {},
				render(width: number): string[] {
					if (hidden) return [];

					let input = 0;
					let output = 0;
					let cost = 0;
					let cacheRead = 0;
					for (const entry of ctx.sessionManager.getBranch()) {
						if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
						const message = entry.message as AssistantMessage;
						input += message.usage.input + message.usage.cacheRead + message.usage.cacheWrite;
						output += message.usage.output;
						cacheRead += message.usage.cacheRead;
						cost += message.usage.cost.total;
					}

					/*
					 * Ordered most important to least, left to right.
					 *
					 * Leftmost is what you glance at mid-task: is it working, is it
					 * allowed to change things, what is it costing. Rightmost is
					 * context you already know — which directory, which branch — and
					 * the clock, which matters least of all because it only tells you
					 * something after the fact.
					 */
					const statuses = footerData.getExtensionStatuses();

					const left: string[] = [];

					// Keep one visible activity cell at the edge so idle state has no
					// unexplained gap and later animation does not shift the row.
					left.push(
						turnStart !== null
							? theme.fg("accent", SPINNER[Math.floor(Date.now() / 100) % SPINNER.length])
							: theme.fg("dim", SPINNER[0]),
					);

					const permission = statuses.get("permission-mode");
					if (permission) left.push(permission);

					// Anything demanding a decision — a held send or spend cap —
					// outranks passive information. Todo
					// progress stays in its above-editor widget instead.
					left.push(...leftExtensionStatuses(statuses));

					const model = ctx.model;
					if (model) {
						left.push(theme.fg(modelColor(model.id), compactModelName(model.id)));
						left.push(theme.fg(`thinking${capitalize(ctx.thinkingLevel ?? "off")}`, thinkingIndicator(ctx.thinkingLevel)));
					} else {
						left.push(theme.fg("error", "no model"));
					}

					const mcp = connectedMcpSummary(connectedMcpNames);
					if (mcp) left.push(theme.fg("accent", mcp));

					// Usage is one stable block pinned to the right edge.
					const right: string[] = [];
					const activeBurnAlias = burnAliasForPiProvider(model?.provider);
					for (const status of burnStatuses) {
						const color = status.severity === "blocked" ? "error" : status.severity === "warning" ? "warning" : "success";
						right.push(theme.fg(color, formatBurnStatus(status, activeBurnAlias)));
					}
					right.push(theme.fg("dim", `${formatUsageIcon("↑", fmtTokens(input))} ${formatUsageIcon("↓", fmtTokens(output))}`));
					if (input > 0) {
						const hit = Math.round((cacheRead / input) * 100);
						right.push(theme.fg(hit >= 50 ? "success" : "dim", formatUsageIcon(STATUS_ICONS.cache, `${hit}%`)));
					}
					right.push(theme.fg("syntaxFunction", formatUsageIcon("$", cost.toFixed(2))));

					const usage = ctx.getContextUsage();
					if (usage && usage.tokens !== null && usage.percent !== null) {
						const remaining = Math.max(0, usage.contextWindow - usage.tokens);
						const percentLeft = 100 - usage.percent;
						let color = "error";
						if (percentLeft >= 50) color = "success";
						else if (percentLeft >= 20) color = "warning";
						right.push(
							theme.fg(color, formatUsageIcon(STATUS_ICONS.context, `${Math.round(usage.percent)}%/${fmtTokens(usage.contextWindow)}`)) +
								theme.fg("dim", ` ${fmtTokens(remaining)} left`),
						);
					}

					const leftText = left.join(SEP);
					const rightText = right.join(SEP);
					const rightWidth = visibleWidth(rightText);
					if (rightWidth >= width) return [truncateToWidth(rightText, width)];
					const leftWidth = Math.max(0, width - rightWidth - 2);
					const fittedLeft = truncateToWidth(leftText, leftWidth, "");
					const gap = width - visibleWidth(fittedLeft) - rightWidth;
					return [fittedLeft + " ".repeat(Math.max(2, gap)) + rightText];
				},
			};
		});
	});

	pi.on("turn_start", () => {
		turnStart = Date.now();
	});

	pi.on("turn_end", () => {
		turnStart = null;
	});
}
