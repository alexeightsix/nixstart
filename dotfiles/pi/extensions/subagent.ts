// @ts-ignore -- Pi supplies Node built-ins to global extensions.
import { spawn } from "node:child_process";
// @ts-ignore -- Pi supplies Node built-ins to global extensions.
import * as fs from "node:fs";
// @ts-ignore -- Pi supplies Node built-ins to global extensions.
import * as path from "node:path";

// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { Type } from "typebox";

import {
	addSubagentUsage,
	captureSubagentEvent,
	emptySubagentUsage,
	MAX_SUBAGENT_TASKS,
	subagentFailed,
	truncateSubagentOutput,
	type SubagentCapture,
} from "../lib/subagent.ts";

declare const process: {
	argv: string[];
	execPath: string;
};

interface SubagentContext {
	cwd: string;
	model?: { provider: string; id: string };
	thinkingLevel?: string;
}

interface SubagentParams {
	task?: string;
	cwd?: string;
	tasks?: TaskInput[];
}

interface SubagentExtensionAPI {
	getAllTools(): Array<{ name: string }>;
	on(event: "session_start", handler: () => void): void;
	registerTool(tool: unknown): void;
}

const READ_ONLY_TOOLS = "read,grep,find,ls,bash,lsp";
const CHILD_PROMPT = `You are a read-only coding subagent working on one delegated task.
The task is your complete brief; you do not have the parent conversation.
Inspect the repository and return concise, concrete findings with file paths and line ranges.
Use LSP for definitions, references, types, symbols, and diagnostics; use lexical search for text.
Do not edit files, make product decisions, or claim the parent task is complete.`;

interface TaskInput {
	task: string;
	cwd?: string;
}

interface TaskResult {
	task: string;
	cwd: string;
	exitCode: number;
	output: string;
	stderr: string;
	capture: SubagentCapture;
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

async function runTask(task: TaskInput, parent: SubagentContext, signal: AbortSignal | undefined): Promise<TaskResult> {
	const cwd = path.resolve(parent.cwd, task.cwd ?? ".");
	const capture: SubagentCapture = { outputs: [], usage: emptySubagentUsage() };
	const args = [
		"--mode", "json",
		"-p",
		"--no-session",
		"--tools", READ_ONLY_TOOLS,
		"--perm", "read-only",
		"--append-system-prompt", CHILD_PROMPT,
	];
	if (parent.model) args.push("--model", `${parent.model.provider}/${parent.model.id}`);
	if (parent.thinkingLevel) args.push("--thinking", parent.thinkingLevel);
	args.push(`Task: ${task.task}`);

	let stderr = "";
	let buffer = "";
	let aborted = false;
	const invocation = piInvocation(args);
	const child = spawn(invocation.command, invocation.args, {
		cwd,
		shell: false,
		stdio: ["ignore", "pipe", "pipe"],
	});

	const consume = (line: string) => {
		if (!line.trim()) return;
		try {
			captureSubagentEvent(capture, JSON.parse(line));
		} catch {
			// Pi's JSON stream may be followed by process diagnostics; stderr is
			// retained separately and malformed stdout records are ignored.
		}
	};
	child.stdout.on("data", (chunk: { toString(): string }) => {
		buffer += chunk.toString();
		const lines = buffer.split("\n");
		buffer = lines.pop() ?? "";
		for (const line of lines) consume(line);
	});
	child.stderr.on("data", (chunk: { toString(): string }) => { stderr += chunk.toString(); });

	const stop = () => {
		aborted = true;
		child.kill("SIGTERM");
	};
	if (signal?.aborted) stop();
	else signal?.addEventListener("abort", stop, { once: true });

	const exitCode = await new Promise<number>((resolve) => {
		child.on("close", (code: number | null) => resolve(code ?? 1));
		child.on("error", () => resolve(1));
	});
	if (buffer.trim()) consume(buffer);
	if (aborted) capture.stopReason = "aborted";

	const fallback = capture.errorMessage || stderr.trim() || "(no output)";
	const output = capture.outputs.at(-1) ?? fallback;
	return { task: task.task, cwd, exitCode, output: truncateSubagentOutput(output), stderr, capture };
}

const TaskSchema = Type.Object({
	task: Type.String({ description: "Self-contained investigation or review task" }),
	cwd: Type.Optional(Type.String({ description: "Working directory, relative to the parent cwd unless absolute" })),
});

function registerSubagentTool(pi: SubagentExtensionAPI) {
	pi.registerTool({
		name: "subagent",
		label: "Subagent",
		description: "Run one or up to four independent read-only coding investigations in isolated Pi contexts using the selected model.",
		promptSnippet: "Delegate bounded independent coding investigation or review to isolated read-only Pi processes",
		promptGuidelines: [
			"Use subagent for substantial independent, read-heavy investigation or review; keep trivial lookups in the parent.",
			"Give each subagent a self-contained brief because it cannot see the parent conversation.",
			"Keep decisions, edits, integration, and final verification in the parent; never delegate overlapping writes.",
		],
		parameters: Type.Object({
			task: Type.Optional(Type.String({ description: "One self-contained task" })),
			cwd: Type.Optional(Type.String({ description: "Working directory for the single task" })),
			tasks: Type.Optional(Type.Array(TaskSchema, {
				description: "Independent tasks to run concurrently",
				minItems: 1,
				maxItems: MAX_SUBAGENT_TASKS,
			})),
		}),
		async execute(
			_id: string,
			params: SubagentParams,
			signal: AbortSignal | undefined,
			onUpdate: ((result: unknown) => void) | undefined,
			ctx: SubagentContext,
		) {
			const hasSingle = typeof params.task === "string" && params.task.trim().length > 0;
			const hasParallel = Array.isArray(params.tasks) && params.tasks.length > 0;
			if (hasSingle === hasParallel) throw new Error("Provide exactly one of task or tasks");
			const tasks: TaskInput[] = hasSingle
				? [{ task: params.task!, cwd: params.cwd }]
				: params.tasks!;

			let completed = 0;
			const results = await Promise.all(tasks.map(async (task) => {
				const result = await runTask(task, ctx, signal);
				completed++;
				onUpdate?.({
					content: [{ type: "text", text: `Subagents: ${completed}/${tasks.length} complete` }],
					details: { completed, total: tasks.length },
				});
				return result;
			}));

			const usage = emptySubagentUsage();
			for (const result of results) addSubagentUsage(usage, result.capture.usage);
			const sections = results.map((result, index) => {
				const failed = subagentFailed(result.exitCode, result.capture);
				return `### ${index + 1}. ${failed ? "Failed" : "Completed"}\n\n${result.output}`;
			});
			return {
				content: [{ type: "text", text: sections.join("\n\n---\n\n") }],
				details: { results: results.map(({ task, cwd, exitCode, capture }) => ({ task, cwd, exitCode, stopReason: capture.stopReason })) },
				usage,
			};
		},
	});
}

export default function (pi: SubagentExtensionAPI) {
	pi.on("session_start", () => {
		if (pi.getAllTools().some((tool) => tool.name === "subagent")) return;
		registerSubagentTool(pi);
	});
}
