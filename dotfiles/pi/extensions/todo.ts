/**
 * /todo — plans the agent writes down, and a live view of it working through them.
 *
 * The agent maintains lists through tools rather than prose, so the plan is
 * structured data that survives compaction. Several lists can be live at once;
 * each is a JSON file scoped to the session.
 *
 *   /todo <goal>   ask the agent to plan the work
 *   /todo          list this session's lists
 *   /progress      every item in every list
 *
 * See docs/todo.md — it is the source of truth for this file.
 */

import * as fs from "node:fs";
import * as path from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

type Status = "pending" | "in_progress" | "done" | "dropped";

interface TodoItem {
	id: number;
	text: string;
	status: Status;
}

interface TodoList {
	title: string;
	created: string;
	items: TodoItem[];
}

const MARK: Record<Status, string> = {
	pending: "○",
	in_progress: "▸",
	done: "✓",
	dropped: "×",
};

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? path.join(process.env.HOME ?? "", ".pi/agent");
}

function slugify(title: string): string {
	return (
		title
			.toLowerCase()
			.replace(/[^a-z0-9]+/g, "-")
			.replace(/^-|-$/g, "")
			.slice(0, 48) || "list"
	);
}

export default function (pi: ExtensionAPI) {
	let dir: string | undefined;

	const listsDir = (): string => {
		const target = dir ?? path.join(agentDir(), "todos", "unknown");
		fs.mkdirSync(target, { recursive: true });
		return target;
	};

	const load = (): { slug: string; list: TodoList }[] => {
		const out: { slug: string; list: TodoList }[] = [];
		let files: string[];
		try {
			files = fs.readdirSync(listsDir()).filter((name) => name.endsWith(".json"));
		} catch {
			return out;
		}
		for (const file of files) {
			try {
				const list = JSON.parse(fs.readFileSync(path.join(listsDir(), file), "utf-8")) as TodoList;
				if (Array.isArray(list.items)) out.push({ slug: file.replace(/\.json$/, ""), list });
			} catch {
				// Half-written or hand-edited; skip rather than fail the view.
			}
		}
		return out.sort((a, b) => a.list.created.localeCompare(b.list.created));
	};

	const save = (slug: string, list: TodoList) => {
		fs.writeFileSync(path.join(listsDir(), `${slug}.json`), `${JSON.stringify(list, null, 2)}\n`, "utf-8");
	};

	const counts = (list: TodoList) => {
		const done = list.items.filter((item) => item.status === "done").length;
		const live = list.items.filter(
			(item) => item.status === "pending" || item.status === "in_progress",
		).length;
		return { done, live, total: list.items.length };
	};

	/** Widget above the editor; progress is not duplicated in the statusline. */
	const render = (ctx: ExtensionContext) => {
		const active = load().filter(({ list }) => counts(list).live > 0);

		if (active.length === 0) {
			ctx.ui.setWidget("todo", undefined);
			ctx.ui.setStatus("todo", undefined);
			return;
		}

		const theme = ctx.ui.theme;
		const lines: string[] = [];

		for (const { list } of active) {
			const { done, total } = counts(list);

			lines.push(`${theme.fg("accent", list.title)}  ${theme.fg("dim", `${done}/${total}`)}`);

			// Show the working edge, not the whole list: the last finished item,
			// everything in flight, and the next couple waiting.
			const current = list.items.findIndex((item) => item.status === "in_progress");
			const anchor = current >= 0 ? current : list.items.findIndex((item) => item.status === "pending");
			const from = Math.max(0, (anchor < 0 ? list.items.length : anchor) - 1);
			for (const item of list.items.slice(from, from + 4)) {
				const color =
					item.status === "done"
						? "success"
						: item.status === "in_progress"
							? "warning"
							: item.status === "dropped"
								? "dim"
								: "muted";
				lines.push(`  ${theme.fg(color, MARK[item.status])} ${theme.fg(color, item.text)}`);
			}
		}

		ctx.ui.setWidget("todo", lines, { placement: "aboveEditor" });
		// Clear statuses published by older loaded versions of this extension.
		ctx.ui.setStatus("todo", undefined);
	};

	pi.on("session_start", async (_event, ctx) => {
		dir = path.join(agentDir(), "todos", ctx.sessionManager.getSessionId());
		render(ctx);
	});

	pi.registerTool({
		name: "todo_write",
		label: "Todo",
		description:
			"Create or replace a todo list for a piece of work. Use one list per distinct piece of work; several may be open at once. Keep items concrete and verifiable.",
		promptSnippet: "Record a plan as a todo list the user can watch",
		promptGuidelines: [
			"Use todo_write when the user asks for a plan or a todo list, or when a task has enough steps that the user would want to see progress.",
			"Mark items in_progress before starting and done immediately after, so the user's view stays accurate.",
		],
		parameters: Type.Object({
			title: Type.String({ description: "Short title for this piece of work." }),
			items: Type.Array(Type.String(), { description: "The steps, in order." }),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const list: TodoList = {
				title: params.title,
				created: new Date().toISOString(),
				items: params.items.map((text, index) => ({ id: index + 1, text, status: "pending" as Status })),
			};
			save(slugify(params.title), list);
			render(ctx);
			return {
				content: [
					{
						type: "text",
						text: `Created "${list.title}" with ${list.items.length} items. Mark each in_progress before starting and done when finished.`,
					},
				],
			};
		},
	});

	pi.registerTool({
		name: "todo_update",
		label: "Todo",
		description:
			"Update one item's status in a todo list, or append a new item. Status is pending, in_progress, done, or dropped.",
		parameters: Type.Object({
			title: Type.String({ description: "Which list, by title." }),
			id: Type.Optional(Type.Number({ description: "Item id to update. Omit when adding." })),
			status: Type.Optional(
				Type.String({ description: "pending | in_progress | done | dropped" }),
			),
			add: Type.Optional(Type.String({ description: "Text of a new item to append." })),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const slug = slugify(params.title);
			const found = load().find((entry) => entry.slug === slug);
			if (!found) {
				throw new Error(`No todo list titled "${params.title}". Existing: ${load().map((e) => e.list.title).join(", ") || "none"}`);
			}

			const { list } = found;
			if (params.add) {
				const nextId = Math.max(0, ...list.items.map((item) => item.id)) + 1;
				list.items.push({ id: nextId, text: params.add, status: "pending" });
			}
			if (params.id !== undefined) {
				const item = list.items.find((candidate) => candidate.id === params.id);
				if (!item) throw new Error(`No item ${params.id} in "${list.title}".`);
				if (params.status) item.status = params.status as Status;
			}

			save(slug, list);
			render(ctx);
			const { done, total } = counts(list);
			return { content: [{ type: "text", text: `"${list.title}" — ${done}/${total} done.` }] };
		},
	});

	pi.registerTool({
		name: "todo_read",
		label: "Todo",
		description:
			"Read back the todo lists for this session. Use this to recover the plan after compaction, or before claiming work is finished.",
		parameters: Type.Object({}),
		async execute() {
			const lists = load();
			return {
				content: [
					{
						type: "text",
						text:
							lists.length === 0
								? "No todo lists in this session."
								: lists
										.map(({ list }) =>
											[
												`${list.title} (${counts(list).done}/${list.items.length})`,
												...list.items.map((item) => `  ${item.id}. [${item.status}] ${item.text}`),
											].join("\n"),
										)
										.join("\n\n"),
					},
				],
			};
		},
	});

	pi.registerCommand("todo", {
		description: "Ask the agent to plan work as a todo list, or list existing lists",
		handler: async (args, ctx) => {
			const goal = args.trim();
			if (!goal) {
				const lists = load();
				ctx.ui.notify(
					lists.length === 0
						? "No todo lists in this session. /todo <goal> to start one."
						: lists
								.map(({ list }) => {
									const { done, total } = counts(list);
									return `${list.title} — ${done}/${total}`;
								})
								.join("\n"),
					"info",
				);
				return;
			}

			pi.sendUserMessage(
				[
					`Plan this work and record it with todo_write before doing anything else:`,
					"",
					goal,
					"",
					"Keep items concrete and verifiable. Mark each in_progress before you start it and done as soon as it is finished, so the list reflects reality while you work.",
				].join("\n"),
			);
		},
	});

	pi.registerCommand("progress", {
		description: "Show every todo list in this session",
		handler: async (_args, ctx) => {
			const lists = load();
			if (lists.length === 0) {
				ctx.ui.notify("No todo lists in this session.", "info");
				return;
			}
			ctx.ui.notify(
				lists
					.map(({ list }) => {
						const { done, total } = counts(list);
						const bar = `${"█".repeat(done)}${"░".repeat(Math.max(0, total - done))}`;
						return [
							`${list.title}  ${bar}  ${done}/${total}`,
							...list.items.map((item) => `  ${MARK[item.status]} ${item.text}`),
						].join("\n");
					})
					.join("\n\n"),
				"info",
			);
		},
	});
}
