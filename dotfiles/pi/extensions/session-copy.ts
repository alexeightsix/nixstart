// Fork sessions into tmux panes; run `/btw` side quests as background children.
declare const process: { argv: string[]; env: Record<string, string | undefined>; execPath: string };

// @ts-ignore -- Pi supplies Node built-ins to global extensions.
import * as fs from "node:fs";
// @ts-ignore -- Pi supplies Node built-ins to global extensions.
import * as path from "node:path";

// @ts-ignore -- Pi supplies this runtime module to global extensions.
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { SessionManager } from "@earendil-works/pi-coding-agent";

import { copySessionName, FORK_DRAFT_ENTRY, tmuxSplitArgs } from "../lib/session-copy.ts";
import {
	captureSubagentEvent,
	emptySubagentUsage,
	truncateSubagentOutput,
	type SubagentCapture,
} from "../lib/subagent.ts";

const DRAFT_CONSUMED_ENTRY = "tmux-fork-draft-consumed";

interface ForkEvent {
	entryId: string;
	position: "before" | "at";
}

interface SavedSession {
	path: string;
	id: string;
	cwd: string;
	name?: string;
	firstMessage: string;
	allMessagesText: string;
}

interface ModelChoice {
	model: { provider: string; id: string };
	thinkingLevel?: string;
}

interface ExecResult {
	stdout: string;
	stderr: string;
	code: number;
}

interface SessionEntryLike {
	id: string;
	parentId: string | null;
	type: string;
	customType?: string;
	data?: { text?: string; sourceId?: string };
	message?: { role?: string; content?: Array<{ type?: string; text?: string }> };
}

function userText(entry: SessionEntryLike): string {
	return entry.message?.content
		?.filter((part) => part.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n") ?? "";
}

function contextText(entries: SessionEntryLike[]): string {
	return entries
		.filter((entry) => entry.type === "message" && entry.message)
		.map((entry) => {
			const role = entry.message?.role ?? "message";
			const text = userText(entry).trim();
			return text ? `${role}: ${text}` : "";
		})
		.filter(Boolean)
		.join("\n\n");
}

function piInvocation(args: string[]): { command: string; args: string[] } {
	const script = process.argv[1];
	if (script && !script.startsWith("/$bunfs/root/") && fs.existsSync(script)) {
		return { command: process.execPath, args: [script, ...args] };
	}
	const executable = path.basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(executable)) return { command: process.execPath, args };
	return { command: "pi", args };
}

function parseJsonEvents(stdout: string): SubagentCapture {
	const capture: SubagentCapture = { outputs: [], usage: emptySubagentUsage() };
	for (const line of stdout.split("\n")) {
		if (!line.trim()) continue;
		try { captureSubagentEvent(capture, JSON.parse(line)); } catch { /* ignore diagnostics */ }
	}
	return capture;
}

function requireTmux(ctx: ExtensionContext): string | undefined {
	const pane = process.env.TMUX_PANE;
	if (process.env.TMUX && pane) return pane;
	ctx.ui.notify("Opening a session copy requires Pi to be running inside tmux.", "error");
	return undefined;
}

export default function (pi: ExtensionAPI) {
	let sideQuests = 0;
	let sideQuestUi: ExtensionContext["ui"] | undefined;

	function renderSideQuestStatus(): void {
		sideQuestUi?.setStatus("btw", sideQuests > 0 ? `btw ${sideQuests}` : undefined);
	}

	async function openCopy(
		ctx: ExtensionContext,
		sessionFile: string,
		name: string,
		prompt?: string,
	): Promise<void> {
		const pane = requireTmux(ctx);
		if (!pane) throw new Error("tmux is required");
		const split = await pi.exec("tmux", tmuxSplitArgs(pane, ctx.cwd, sessionFile, name, prompt));
		if (split.code !== 0) throw new Error(split.stderr.trim() || "tmux could not create the pane");
		const childPane = split.stdout.trim();
		if (childPane) await pi.exec("tmux", ["select-pane", "-t", childPane, "-T", name]);
	}

	pi.on("session_start", (_event: unknown, ctx: ExtensionContext) => {
		sideQuestUi = ctx.ui;
		sideQuests = 0;
		renderSideQuestStatus();
		if (ctx.mode !== "tui") return;
		const branch = ctx.sessionManager.getBranch() as SessionEntryLike[];
		const consumed = new Set(
			branch
				.filter((entry) => entry.type === "custom" && entry.customType === DRAFT_CONSUMED_ENTRY)
				.map((entry) => entry.data?.sourceId)
				.filter((id): id is string => typeof id === "string"),
		);
		const draft = [...branch].reverse().find(
			(entry) => entry.type === "custom" && entry.customType === FORK_DRAFT_ENTRY && !consumed.has(entry.id),
		);
		if (draft?.data?.text) {
			ctx.ui.setEditorText(draft.data.text);
			pi.appendEntry(DRAFT_CONSUMED_ENTRY, { sourceId: draft.id });
			ctx.ui.notify("Fork ready in this pane. Edit or submit the restored prompt.", "info");
		}
	});

	pi.on("session_before_fork", async (event: ForkEvent, ctx: ExtensionContext) => {
		// `/clone` deliberately retains Pi's built-in same-pane behavior.
		if (event.position !== "before") return;
		const pane = requireTmux(ctx);
		if (!pane) return { cancel: true };

		const currentFile = ctx.sessionManager.getSessionFile();
		const selected = ctx.sessionManager.getEntry(event.entryId) as SessionEntryLike | undefined;
		if (!currentFile || !selected || selected.message?.role !== "user") {
			ctx.ui.notify("This session must be saved before it can be forked.", "error");
			return { cancel: true };
		}

		try {
			let forkedFile: string | undefined;
			if (selected.parentId) {
				forkedFile = SessionManager.open(currentFile, ctx.sessionManager.getSessionDir())
					.createBranchedSession(selected.parentId);
			} else {
				const fresh = SessionManager.create(ctx.cwd, ctx.sessionManager.getSessionDir());
				fresh.newSession({ parentSession: currentFile });
				forkedFile = fresh.getSessionFile();
			}
			if (!forkedFile) throw new Error("Pi could not create the forked session file");

			const forked = SessionManager.open(forkedFile, ctx.sessionManager.getSessionDir());
			const name = copySessionName(ctx.sessionManager.getSessionName(), ctx.sessionManager.getSessionId());
			forked.appendSessionInfo(name);
			forked.appendCustomEntry(FORK_DRAFT_ENTRY, { text: userText(selected) });
			await openCopy(ctx, forkedFile, name);
			ctx.ui.notify(`Opened ${name} in a right-hand pane.`, "info");
		} catch (error) {
			ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
		}
		return { cancel: true };
	});

	pi.registerCommand("btw", {
		description: "Launch a writable background side quest",
		handler: async (args: string, ctx: ExtensionContext) => {
			const task = args.trim() || await ctx.ui.input("What should the side quest do?", "Self-contained task");
			if (!task?.trim()) return;

			const contextChoice = await ctx.ui.select("What context should it use?", [
				"Parent conversation",
				"No conversation",
				"Other saved session",
			]);
			if (!contextChoice) return;

			let inherited = "";
			if (contextChoice === "Parent conversation") {
				inherited = contextText(ctx.sessionManager.getBranch() as SessionEntryLike[]);
			} else if (contextChoice === "Other saved session") {
				const sessions = ((await SessionManager.listAll()) as SavedSession[]).filter(
					(session: SavedSession) => session.path !== ctx.sessionManager.getSessionFile(),
				);
				if (sessions.length === 0) {
					ctx.ui.notify("No other saved sessions found.", "warning");
					return;
				}
				const labels = sessions.map((session: SavedSession) =>
					`${(session.name ?? session.firstMessage) || session.id.slice(0, 8)} — ${session.cwd}`,
				);
				const selected = await ctx.ui.select("Which session should provide context?", labels);
				if (!selected) return;
				inherited = sessions[labels.indexOf(selected)]?.allMessagesText ?? "";
			}

			const models: ModelChoice[] = ctx.scopedModels.length > 0
				? ctx.scopedModels as ModelChoice[]
				: (await ctx.modelRegistry.getAvailable()).map((model: ModelChoice["model"]) => ({ model }));
			if (models.length === 0) {
				ctx.ui.notify("No authenticated models available.", "error");
				return;
			}
			const modelLabels = models.map(({ model, thinkingLevel }: ModelChoice) =>
				`${model.provider}/${model.id}${thinkingLevel ? `:${thinkingLevel}` : ""}`,
			);
			const current = ctx.model
				? modelLabels.find((label: string) => label.startsWith(`${ctx.model?.provider}/${ctx.model?.id}`))
				: undefined;
			const orderedLabels = current
				? [current, ...modelLabels.filter((label: string) => label !== current)]
				: modelLabels;
			const selectedModel = await ctx.ui.select("What model should it use?", orderedLabels);
			if (!selectedModel) return;

			// Keep argv below platform limits. The newest/most relevant context is at
			// the tail of a transcript, so retain that end when a long session is chosen.
			if (inherited.length > 80_000) inherited = `[Earlier context omitted]\n${inherited.slice(-80_000)}`;
			const prompt = [
				"You are a writable coding side quest running independently in the same working directory as the parent agent.",
				"Complete the task, verify your changes, and return a concise result with files changed and tests run.",
				inherited ? `Context copied from the selected conversation:\n\n${inherited}` : "No parent conversation context was requested.",
				`Task:\n${task.trim()}`,
			].join("\n\n");
			const childArgs = [
				"--mode", "json", "-p", "--no-session", "--perm", "all",
				"--model", selectedModel,
				prompt,
			];
			const invocation = piInvocation(childArgs);
			sideQuests++;
			renderSideQuestStatus();
			ctx.ui.notify(`Started side quest with ${selectedModel}.`, "info");

			void pi.exec(invocation.command, invocation.args).then((result: ExecResult) => {
				const capture = parseJsonEvents(result.stdout);
				const output = truncateSubagentOutput(
					capture.outputs.at(-1) ?? capture.errorMessage ?? result.stderr.trim() ?? "(no output)",
					12 * 1024,
				);
				pi.sendMessage({
					customType: "btw-result",
					content: `Side quest finished: ${task.trim()}\n\n${output}`,
					display: true,
				}, { deliverAs: "followUp" });
				ctx.ui.notify("Side quest finished; result added to this conversation.", result.code === 0 ? "info" : "warning");
			}).catch((error: unknown) => {
				ctx.ui.notify(`Side quest failed: ${error instanceof Error ? error.message : String(error)}`, "error");
			}).finally(() => {
				sideQuests = Math.max(0, sideQuests - 1);
				renderSideQuestStatus();
			});
		},
	});
}
