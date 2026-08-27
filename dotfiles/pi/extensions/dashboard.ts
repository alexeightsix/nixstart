/**
 * /dash — see everything the agent currently has.
 *
 * One scrollable overlay: the model and its window, the models you can switch
 * to, permission state and how far grants reach, working directory, tools,
 * skills, MCP servers and which of them are actually loaded, and what the
 * session has spent.
 *
 * Also owns the `mcp 2/5 figma, linear` statusline segment. MCP servers here are
 * lazy, so a server counts as loaded exactly when something first calls it.
 *
 * See docs/dashboard.md — it is the source of truth for this file.
 */

import * as fs from "node:fs";
import * as path from "node:path";

import type { AssistantMessage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { type Focusable, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

import { formatColumns } from "../lib/layout.ts";
import { formatRecentSkills, recentSkillsFromEntries, type SkillHistoryEntry } from "../lib/statusline-skills.ts";
import { summarize } from "./housekeeping.ts";

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? path.join(process.env.HOME ?? "", ".pi/agent");
}

function configuredMcpServers(): string[] {
	for (const candidate of [
		path.join(agentDir(), "mcp.json"),
		path.join(process.cwd(), ".mcp.json"),
	]) {
		try {
			const parsed = JSON.parse(fs.readFileSync(candidate, "utf-8")) as {
				mcpServers?: Record<string, unknown>;
			};
			const names = Object.keys(parsed.mcpServers ?? {});
			if (names.length > 0) return names;
		} catch {
			// Not present or not readable; try the next location.
		}
	}
	return [];
}

function fmtTokens(n: number): string {
	if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
	if (n >= 1000) return `${(n / 1000).toFixed(1)}k`;
	return `${n}`;
}

function fmtBytes(bytes: number): string {
	if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)}G`;
	if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(1)}M`;
	if (bytes >= 1024) return `${(bytes / 1024).toFixed(0)}K`;
	return `${bytes}B`;
}

function displayPath(target: string): string {
	const home = process.env.HOME;
	if (home && target === home) return "~";
	if (home && target.startsWith(`${home}/`)) return `~/${target.slice(home.length + 1)}`;
	return target;
}

/** A read-only, scrollable panel. Escape or q closes it. */
class DashboardComponent implements Focusable {
	focused = false;
	private offset = 0;
	private readonly lines: string[];
	private readonly theme: Theme;
	private readonly done: (result: undefined) => void;

	constructor(lines: string[], theme: Theme, done: (result: undefined) => void) {
		this.lines = lines;
		this.theme = theme;
		this.done = done;
	}

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
		const inner = Math.max(20, Math.min(width, 96) - 2);
		const theme = this.theme;
		const pad = (text: string) => text + " ".repeat(Math.max(0, inner - visibleWidth(text)));
		const row = (content: string) =>
			theme.fg("border", "│") + pad(truncateToWidth(content, inner)) + theme.fg("border", "│");

		const out: string[] = [];
		out.push(theme.fg("border", `╭${"─".repeat(inner)}╮`));
		out.push(row(` ${theme.fg("accent", "what the agent has")}`));
		out.push(theme.fg("border", `├${"─".repeat(inner)}┤`));

		const window = this.lines.slice(this.offset, this.offset + this.visibleCount());
		for (const line of window) out.push(row(line));

		out.push(theme.fg("border", `├${"─".repeat(inner)}┤`));
		const more = this.maxOffset() > 0 ? `  ${this.offset + 1}-${this.offset + window.length} of ${this.lines.length}  ↑↓ scroll` : "";
		out.push(row(theme.fg("dim", `  esc close${more}`)));
		out.push(theme.fg("border", `╰${"─".repeat(inner)}╯`));
		return out;
	}
}

export default function (pi: ExtensionAPI) {
	const configured = configuredMcpServers();
	const loaded = new Set<string>();

	const publishMcpStatus = (ctx: ExtensionContext) => {
		// pi-mcp-adapter already contributes its own `MCP 0/5` count. Naming the
		// loaded servers is the part it does not do, so only add that, and only
		// once there is something to name — otherwise the line carries the same
		// count twice.
		if (loaded.size === 0) {
			ctx.ui.setStatus("mcp", undefined);
			return;
		}
		ctx.ui.setStatus("mcp", ctx.ui.theme.fg("success", [...loaded].join(", ")));
	};

	pi.on("session_start", async (_event, ctx) => {
		publishMcpStatus(ctx);
	});

	// A lazy server is loaded exactly when something first calls into it. The
	// adapter proxies MCP calls, so the server name arrives in the arguments.
	pi.on("tool_execution_start", async (event, ctx) => {
		const name = (event as { toolName?: string }).toolName ?? "";
		const blob = JSON.stringify((event as { input?: unknown }).input ?? {});
		let changed = false;
		for (const server of configured) {
			if (loaded.has(server)) continue;
			if (name.includes(server) || new RegExp(`"${server}"`).test(blob)) {
				loaded.add(server);
				changed = true;
			}
		}
		if (changed) publishMcpStatus(ctx);
	});

	pi.registerCommand("dash", {
		description: "Show everything the agent currently has",
		handler: async (_args: string, ctx: ExtensionCommandContext) => {
			const theme = ctx.ui.theme;
			const lines: string[] = [];
			const section = (title: string) => {
				if (lines.length > 0) lines.push("");
				lines.push(theme.fg("accent", ` ${title}`));
			};
			const item = (label: string, value: string) =>
				lines.push(`   ${theme.fg("dim", label.padEnd(12))} ${value}`);

			section("model");
			const model = ctx.model;
			if (model) {
				item("active", `${model.provider}/${model.id}`);
				item("window", `${fmtTokens(model.contextWindow)} tokens · max out ${fmtTokens(model.maxTokens)}`);
				item("thinking", ctx.thinkingLevel ?? "off");
				const usage = ctx.getContextUsage();
				if (usage && usage.tokens !== null && usage.percent !== null) {
					item(
						"used",
						`${fmtTokens(usage.tokens)} (${Math.round(usage.percent)}%) · ${fmtTokens(usage.contextWindow - usage.tokens)} left`,
					);
				}
			} else {
				item("active", theme.fg("error", "none"));
			}

			section(`switchable models (${ctx.scopedModels.length})`);
			for (const scoped of ctx.scopedModels) {
				const marker = scoped.model.id === model?.id ? theme.fg("success", "●") : theme.fg("dim", "○");
				lines.push(
					`   ${marker} ${scoped.model.provider}/${scoped.model.id} ${theme.fg("dim", `· ${fmtTokens(scoped.model.contextWindow)}`)}`,
				);
			}

			section("where");
			item("cwd", displayPath(ctx.cwd));
			item("trusted", ctx.isProjectTrusted() ? "yes" : "no");

			section(`mcp (${loaded.size}/${configured.length} loaded)`);
			for (const server of configured) {
				const on = loaded.has(server);
				lines.push(
					`   ${on ? theme.fg("success", "●") : theme.fg("dim", "○")} ${server} ${theme.fg("dim", on ? "loaded" : "lazy, not yet used")}`,
				);
			}

			const tools = pi.getActiveTools();
			section(`tools (${tools.length})`);
			for (const row of formatColumns(tools, 18, 4)) lines.push(`   ${row}`);

			const recentSkills = recentSkillsFromEntries(
				ctx.sessionManager.getBranch() as SkillHistoryEntry[],
				"statusline-skill-loaded",
			);
			section("recent skills");
			lines.push(`   ${formatRecentSkills(recentSkills) || theme.fg("dim", "none this session")}`);

			section("disk");
			const disk = summarize();
			for (const store of disk) {
				if (store.files === 0) continue;
				lines.push(
					`   ${theme.fg("dim", store.label.padEnd(12))} ${fmtBytes(store.bytes).padStart(6)}  ${theme.fg("dim", `${store.files} files`)}`,
				);
			}
			lines.push(theme.fg("dim", "   /gc to prune — pi does not do it on its own"));

			section("spend");
			let input = 0;
			let output = 0;
			let cost = 0;
			for (const entry of ctx.sessionManager.getBranch()) {
				if (entry.type !== "message" || entry.message.role !== "assistant") continue;
				const message = entry.message as AssistantMessage;
				input += message.usage.input + message.usage.cacheRead + message.usage.cacheWrite;
				output += message.usage.output;
				cost += message.usage.cost.total;
			}
			item("tokens", `↑${fmtTokens(input)}  ↓${fmtTokens(output)}`);
			item("cost", theme.fg("syntaxFunction", `$${cost.toFixed(3)}`));
			lines.push(theme.fg("dim", "   /stats for the per-model breakdown"));

			await ctx.ui.custom<undefined>(
				(_tui, componentTheme, _keybindings, done) => new DashboardComponent(lines, componentTheme, done),
				{ overlay: true },
			);
		},
	});
}
