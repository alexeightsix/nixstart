// @ts-ignore -- These built-ins are available in the Node runtime used by the test command.
import assert from "node:assert/strict";
// @ts-ignore -- These built-ins are available in the Node runtime used by the test command.
import { describe, it } from "node:test";

import {
	buildTldrPrompt,
	buildTldrSnapshot,
	canReuseTldr,
	latestTldrCache,
	TLDR_CACHE_ENTRY_TYPE,
	TLDR_CACHE_RETENTION,
	TLDR_SKILL_MARKER,
	TLDR_TOOL_NAME,
	tldrProviderSessionId,
	type TldrCacheData,
	type TldrSessionEntry,
} from "../lib/tldr.ts";

const text = (role: string, value: string): TldrSessionEntry => ({
	type: "message",
	message: { role, content: [{ type: "text", text: value }] },
});

describe("session TLDR snapshot", () => {
	it("changes when meaningful conversation is added", () => {
		const entries = [
			text("user", "Build a branch indicator."),
			text("assistant", "Implemented and tested it."),
		];
		const before = buildTldrSnapshot(entries);
		const after = buildTldrSnapshot([
			...entries,
			text("user", "Now add cache reuse."),
		]);
		assert.notEqual(before.fingerprint, after.fingerprint);
		assert.equal(before.sourceSections, 2);
		assert.match(before.conversationText, /Build a branch indicator/);
	});

	it("ignores the skill prompt, TLDR tool exchange, cache entry, and rendered answer", () => {
		const meaningful = [
			text("user", "Remember decision alpha."),
			text("assistant", "Decision alpha is recorded."),
		];
		const before = buildTldrSnapshot(meaningful);
		const cache: TldrCacheData = {
			fingerprint: before.fingerprint,
			sourceSections: before.sourceSections,
			summary: "## Decisions\n- alpha",
			updatedAt: 123,
		};
		const after = buildTldrSnapshot([
			...meaningful,
			text("user", `<!-- ${TLDR_SKILL_MARKER} -->\nCall the tool.`),
			{
				type: "message",
				message: {
					role: "assistant",
					content: [{ type: "toolCall", name: TLDR_TOOL_NAME, arguments: {} }],
				},
			},
			{ type: "custom", customType: TLDR_CACHE_ENTRY_TYPE, data: cache },
			{
				type: "message",
				message: { role: "toolResult", toolName: TLDR_TOOL_NAME, content: cache.summary },
			},
			text("assistant", cache.summary),
		]);
		assert.equal(after.fingerprint, before.fingerprint);
		assert.equal(after.conversationText, before.conversationText);
	});

	it("ignores a raw skill command", () => {
		assert.equal(
			buildTldrSnapshot([text("user", "/skill:tldr")]).conversationText,
			"",
		);
	});
});

describe("session TLDR cache", () => {
	it("restores the latest valid branch cache and reuses only an exact snapshot", () => {
		const snapshot = buildTldrSnapshot([text("user", "alpha")]);
		const oldCache: TldrCacheData = {
			fingerprint: "old",
			sourceSections: 1,
			summary: "old",
			updatedAt: 1,
		};
		const currentCache: TldrCacheData = {
			fingerprint: snapshot.fingerprint,
			sourceSections: 1,
			summary: "current",
			updatedAt: 2,
		};
		const entries: TldrSessionEntry[] = [
			{ type: "custom", customType: TLDR_CACHE_ENTRY_TYPE, data: oldCache },
			{ type: "custom", customType: "other", data: currentCache },
			{ type: "custom", customType: TLDR_CACHE_ENTRY_TYPE, data: currentCache },
		];
		assert.deepEqual(latestTldrCache(entries), currentCache);
		assert.equal(canReuseTldr(currentCache, snapshot), true);
		assert.equal(canReuseTldr(oldCache, snapshot), false);
	});

	it("builds a bounded, structured summarization instruction around the snapshot", () => {
		const snapshot = buildTldrSnapshot([text("user", "Ship beta")]);
		const prompt = buildTldrPrompt(snapshot);
		assert.match(prompt, /Goal, Decisions, Progress, Open questions, Next steps/);
		assert.match(prompt, /<conversation>\nUser: Ship beta\n<\/conversation>/);
	});

	it("uses long provider caching with a stable TLDR session suffix", () => {
		assert.equal(TLDR_CACHE_RETENTION, "long");
		assert.equal(tldrProviderSessionId("session-123"), "session-123:tldr");
	});
});
