// @ts-ignore -- Pi supplies this runtime module to global extensions.
import type { Usage } from "@earendil-works/pi-ai";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { Container, Markdown, Text } from "@earendil-works/pi-tui";
// @ts-ignore -- Pi supplies this runtime module to global extensions.
import { Type } from "typebox";

import {
	buildTldrPrompt,
	buildTldrSnapshot,
	canReuseTldr,
	latestTldrCache,
	TLDR_CACHE_ENTRY_TYPE,
	TLDR_CACHE_RETENTION,
	TLDR_TOOL_NAME,
	tldrProviderSessionId,
	type TldrCacheData,
	type TldrSessionEntry,
} from "../lib/tldr.ts";

interface TldrDetails {
	cacheHit: boolean;
	fingerprint: string;
	sourceSections: number;
	summary: string;
}

interface TldrResult extends TldrDetails {
	usage?: Usage;
}

interface TldrContentBlock {
	text?: string;
	type?: string;
}

export default function tldrExtension(pi: ExtensionAPI) {
	async function getTldr(
		ctx: ExtensionContext,
		signal?: AbortSignal,
	): Promise<TldrResult> {
		const entries = ctx.sessionManager.getBranch() as TldrSessionEntry[];
		const snapshot = buildTldrSnapshot(entries);
		if (!snapshot.conversationText.trim())
			throw new Error("No meaningful conversation to summarize yet.");

		const cache = latestTldrCache(entries);
		if (canReuseTldr(cache, snapshot)) {
			return {
				cacheHit: true,
				fingerprint: snapshot.fingerprint,
				sourceSections: cache.sourceSections,
				summary: cache.summary,
			};
		}

		if (!ctx.model) throw new Error("No active model is available for TLDR.");
		const response = await ctx.modelRegistry.complete(
			ctx.model,
			{
				messages: [
					{
						role: "user" as const,
						content: [
							{ type: "text" as const, text: buildTldrPrompt(snapshot) },
						],
						timestamp: Date.now(),
					},
				],
			},
			{
				cacheRetention: TLDR_CACHE_RETENTION,
				maxTokens: 1_600,
				reasoningEffort: "low",
				sessionId: tldrProviderSessionId(
					ctx.sessionManager.getSessionId(),
				),
				signal,
			},
		);
		const summaryParts: string[] = [];
		for (const block of response.content as TldrContentBlock[]) {
			if (block.type === "text" && typeof block.text === "string")
				summaryParts.push(block.text);
		}
		const summary = summaryParts.join("\n").trim();
		if (!summary) throw new Error("The TLDR model returned no text.");

		const cacheData: TldrCacheData = {
			fingerprint: snapshot.fingerprint,
			sourceSections: snapshot.sourceSections,
			summary,
			updatedAt: Date.now(),
		};
		pi.appendEntry(TLDR_CACHE_ENTRY_TYPE, cacheData);
		return {
			cacheHit: false,
			fingerprint: snapshot.fingerprint,
			sourceSections: snapshot.sourceSections,
			summary,
			usage: response.usage,
		};
	}

	pi.registerTool({
		name: TLDR_TOOL_NAME,
		label: "Session TLDR",
		description:
			"Summarize the active session branch, or return its cached TLDR when no meaningful conversation changed.",
		parameters: Type.Object({}),
		async execute(
			_toolCallId: string,
			_params: Record<string, never>,
			signal: AbortSignal | undefined,
			_onUpdate: unknown,
			ctx: ExtensionContext,
		) {
			const result = await getTldr(ctx, signal);
			return {
				content: [{ type: "text" as const, text: result.summary }],
				details: result,
				terminate: true,
				...(result.usage ? { usage: result.usage } : {}),
			};
		},
		renderResult(
			result: { details?: TldrDetails },
			options: { isPartial?: boolean },
			theme: Theme,
		) {
			if (options.isPartial)
				return new Text(theme.fg("warning", "Preparing session TLDR…"), 0, 0);
			const details = result.details;
			if (!details)
				return new Text(theme.fg("error", "TLDR result unavailable"), 0, 0);
			const container = new Container();
			container.addChild(
				new Text(
					theme.fg(
						details.cacheHit ? "success" : "accent",
						details.cacheHit ? "cached · unchanged" : "refreshed",
					),
					0,
					0,
				),
			);
			container.addChild(
				new Markdown(details.summary, 0, 0, getMarkdownTheme()),
			);
			return container;
		},
	});
}
