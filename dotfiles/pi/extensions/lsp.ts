/**
 * Read-only semantic code navigation through gopls and TypeScript's native
 * Go language server. See docs/lsp.md — it is the source of truth.
 */

// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { StringEnum } from "@earendil-works/pi-ai";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { Type } from "typebox";

import { LspManager, type LspAction } from "../lib/lsp-client.ts";

interface LspExtensionContext {
	cwd: string;
	ui: {
		setStatus(key: string, value: string | undefined): void;
		theme: { fg(color: string, value: string): string };
	};
}

interface LspExtensionAPI {
	on(
		event: "session_start",
		handler: (event: unknown, ctx: LspExtensionContext) => unknown,
	): void;
	on(event: "session_shutdown", handler: () => unknown): void;
	registerTool(tool: unknown): void;
}

interface LspToolParams {
	action: string;
	column?: number;
	line?: number;
	path: string;
	symbol?: string;
}

const ACTIONS = ["hover", "definition", "references", "symbols", "diagnostics"] as const;

export default function (pi: LspExtensionAPI) {
	const manager = new LspManager();

	pi.registerTool({
		name: "lsp",
		label: "LSP",
		description:
			"Query gopls or TypeScript's native Go language server for hover information, definitions, references, document symbols, or diagnostics.",
		promptSnippet: "Use language servers for symbol-aware code navigation and diagnostics",
		promptGuidelines: [
			"Prefer lsp over text search when answering where a symbol is defined, how it is typed, which references resolve to it, or which diagnostics apply.",
			"Use the symbol parameter with a one-based line when possible; use column only when the source spelling cannot identify the position.",
		],
		parameters: Type.Object({
			action: StringEnum(ACTIONS, {
				description: "Semantic query to run.",
			}),
			path: Type.String({ description: "Source file path, absolute or relative to Pi's cwd." }),
			line: Type.Optional(
				Type.Number({ description: "One-based source line. Required for position-based actions." }),
			),
			symbol: Type.Optional(
				Type.String({
					description:
						"Substring on the selected line used to resolve the column. Add #N for the Nth occurrence.",
				}),
			),
			column: Type.Optional(
				Type.Number({
					description:
						"One-based source column. Used when symbol is omitted; required for position-based actions without symbol.",
				}),
			),
		}),
		async execute(
			_toolCallId: string,
			params: LspToolParams,
			signal: AbortSignal | undefined,
			_onUpdate: unknown,
			ctx: LspExtensionContext,
		) {
			try {
				const text = await manager.query(
					{
						action: params.action as LspAction,
						path: params.path,
						line: params.line,
						symbol: params.symbol,
						column: params.column,
					},
					ctx.cwd,
					signal,
				);
				return { content: [{ type: "text", text }], details: { action: params.action } };
			} catch (error) {
				return {
					content: [{ type: "text", text: error instanceof Error ? error.message : String(error) }],
					details: { action: params.action },
					isError: true,
				};
			}
		},
	});

	pi.on("session_start", async (_event: unknown, ctx: LspExtensionContext) => {
		ctx.ui.setStatus(
			"lsp",
			ctx.ui.theme.fg("dim", "LSP ") + ctx.ui.theme.fg("success", "✓"),
		);
	});

	pi.on("session_shutdown", async () => manager.close());
}
