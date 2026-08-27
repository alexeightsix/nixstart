/**
 * Keep questions awaiting the user's answer visible above the editor.
 *
 * The model pins questions through the `question` tool. State is persisted as a
 * custom session entry, restored on resume, and cleared by the next ordinary
 * interactive prompt. See docs/questions.md — it is the source of truth.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

import {
	isOrdinaryAnswer,
	normalizeQuestions,
	type PendingQuestions,
	questionRows,
} from "../lib/questions.ts";

const ENTRY_TYPE = "pinned-questions";
const WIDGET_KEY = "questions";

interface PersistedQuestions {
	pending?: PendingQuestions;
}

export default function (pi: ExtensionAPI) {
	let pending: PendingQuestions | undefined;

	const render = (ctx: ExtensionContext) => {
		if (!pending) {
			ctx.ui.setWidget(WIDGET_KEY, undefined);
			return;
		}
		const [heading, ...questions] = questionRows(pending);
		ctx.ui.setWidget(
			WIDGET_KEY,
			[
				ctx.ui.theme.fg("warning", ctx.ui.theme.bold(heading)),
				...questions.map((question) => ctx.ui.theme.fg("text", question)),
			],
			{ placement: "aboveEditor" },
		);
	};

	const persist = () => {
		pi.appendEntry(ENTRY_TYPE, { pending } satisfies PersistedQuestions);
	};

	const clear = (ctx: ExtensionContext) => {
		if (!pending) return;
		pending = undefined;
		persist();
		render(ctx);
	};

	pi.on("session_start", async (_event, ctx) => {
		const latest = ctx.sessionManager
			.getEntries()
			.filter(
				(entry: { type: string; customType?: string }) =>
					entry.type === "custom" && entry.customType === ENTRY_TYPE,
			)
			.pop() as { data?: PersistedQuestions } | undefined;
		pending = latest?.data?.pending;
		render(ctx);
	});

	pi.on("input", async (event, ctx) => {
		if (pending && isOrdinaryAnswer(event.text, event.source)) clear(ctx);
		return { action: "continue" as const };
	});

	pi.registerTool({
		name: "question",
		label: "Question",
		description:
			"Pin one or more questions that require the user's answer in a persistent widget above the editor.",
		promptSnippet: "Keep questions awaiting the user's answer visible beside the editor",
		promptGuidelines: [
			"Call question whenever your response asks the user for information, confirmation, or a decision. Pin every outstanding question before ending the turn so it cannot be lost when the transcript scrolls.",
		],
		parameters: Type.Object({
			title: Type.Optional(Type.String({ description: "Short heading for the group of questions." })),
			questions: Type.Array(Type.String({ description: "One concrete question requiring an answer." }), {
				minItems: 1,
			}),
		}),
		async execute(_id, params, _signal, _onUpdate, ctx) {
			const next = normalizeQuestions(params.questions, params.title);
			if (!next) throw new Error("At least one non-empty question is required.");
			pending = next;
			persist();
			render(ctx);
			return {
				content: [
					{
						type: "text",
						text: `Pinned ${pending.questions.length} question${pending.questions.length === 1 ? "" : "s"}. End the turn and wait for the user's answer.`,
					},
				],
			};
		},
	});

	pi.registerCommand("questions", {
		description: "Show or clear questions awaiting your answer",
		handler: async (args, ctx) => {
			if (args.trim() === "clear") {
				if (!pending) {
					ctx.ui.notify("No questions are awaiting your answer.", "info");
					return;
				}
				clear(ctx);
				ctx.ui.notify("Cleared the pinned questions.", "info");
				return;
			}
			ctx.ui.notify(
				pending ? questionRows(pending).join("\n") : "No questions are awaiting your answer.",
				"info",
			);
		},
	});
}
