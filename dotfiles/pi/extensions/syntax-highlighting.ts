/**
 * Syntax highlighting for rendered code.
 *
 * - Bash tool-call commands use Pi's syntax palette instead of one flat colour.
 * - Embedded heredoc bodies switch to their interpreter/file/delimiter language.
 * - Edit diffs keep diff-coloured gutters without flattening source syntax.
 * - Unlabelled Markdown fences get a conservative render-only language label.
 *
 * Execution, output rendering, truncation, timing and prompt metadata remain
 * Pi's built-in behavior; this extension replaces only the relevant renderers.
 *
 * See docs/code-rendering.md — it is the source of truth for this file.
 */

import {
	copyToClipboard,
	createBashToolDefinition,
	createEditToolDefinition,
	getLanguageFromPath,
	highlightCode,
	type ExtensionAPI,
	type ExtensionContext,
	type Theme,
} from "@earendil-works/pi-coding-agent";
import { Box, Text } from "@earendil-works/pi-tui";

import { latestCodeSnippet } from "../lib/snippet.ts";
import {
	annotateUnlabelledFences,
	filePathFromToolArgs,
	renderDiffWithSyntax,
	splitShellLanguages,
	type DiffLineKind,
} from "../lib/syntax.ts";

interface EditHighlightState {
	callComponent?: Box & {
		preview?: { diff: string; firstChangedLine?: number } | { error: string };
	};
}

const DIFF_COLORS = {
	added: "toolDiffAdded",
	removed: "toolDiffRemoved",
	context: "toolDiffContext",
} as const;

function syntaxHighlightEditPreview(
	state: EditHighlightState,
	filePath: string | undefined,
	theme: Theme,
): void {
	const call = state.callComponent;
	const preview = call?.preview;
	if (!call || !preview || "error" in preview || !filePath) return;

	const body = call.children.at(-1);
	if (!(body instanceof Text)) return;

	try {
		body.setText(
			renderDiffWithSyntax(preview.diff, filePath, {
				language: getLanguageFromPath(filePath),
				highlight: (code, language) => highlightCode(code, language),
				styleDiff: (kind: DiffLineKind, text: string) => theme.fg(DIFF_COLORS[kind], text),
			}),
		);
	} catch {
		// Keep Pi's built-in diff renderer if language highlighting fails.
	}
}

export default function (pi: ExtensionAPI) {
	pi.registerMarkdownTransformer(annotateUnlabelledFences);

	const copyLatest = async (ctx: ExtensionContext) => {
		const code = latestCodeSnippet(ctx.sessionManager.getBranch());
		if (!code) {
			ctx.ui.notify("No Bash command or fenced code block to copy.", "info");
			return;
		}
		try {
			await copyToClipboard(code);
			ctx.ui.notify("Copied the most recent code snippet.", "info");
		} catch {
			ctx.ui.notify("Could not copy the code snippet to the system clipboard.", "error");
		}
	};

	const builtIn = createBashToolDefinition(process.cwd());
	pi.registerTool({
		...builtIn,
		renderCall(args, theme, context) {
			const state = context.state;
			if (context.executionStarted && state.startedAt === undefined) {
				state.startedAt = Date.now();
				state.endedAt = undefined;
			}

			const command = typeof args?.command === "string" ? args.command : undefined;
			let lines: string[];
			if (command === undefined) {
				lines = [theme.fg("error", "[invalid command]")];
			} else if (command.length === 0) {
				lines = [theme.fg("toolOutput", "...")];
			} else {
				lines = splitShellLanguages(command).flatMap((segment) =>
					highlightCode(segment.code, segment.language),
				);
			}

			lines[0] =
				theme.fg("toolTitle", theme.bold("$ ")) +
				(lines[0] ?? "") +
				theme.fg("dim", "  [Ctrl+Alt+C copy]");
			if (args?.timeout && lines.length > 0) {
				lines[lines.length - 1] += theme.fg("muted", ` (timeout ${args.timeout}s)`);
			}

			const text = (context.lastComponent as Text | undefined) ?? new Text("", 0, 0);
			text.setText(lines.join("\n"));
			return text;
		},
	});

	const builtInEdit = createEditToolDefinition(process.cwd());
	pi.registerTool({
		...builtInEdit,
		renderCall(args, theme, context) {
			const component = builtInEdit.renderCall!(args, theme, context);
			syntaxHighlightEditPreview(context.state as EditHighlightState, filePathFromToolArgs(args), theme);
			return component;
		},
		renderResult(result, options, theme, context) {
			const component = builtInEdit.renderResult!(result, options, theme, context);
			syntaxHighlightEditPreview(
				context.state as EditHighlightState,
				filePathFromToolArgs(context.args),
				theme,
			);
			return component;
		},
	});

	pi.registerCommand("copy-code", {
		description: "Copy the most recent Bash command or fenced code block",
		handler: async (_args, ctx) => copyLatest(ctx),
	});
	pi.registerShortcut("ctrl+alt+c", {
		description: "Copy the most recent rendered code snippet",
		handler: (ctx) => void copyLatest(ctx),
	});
}
