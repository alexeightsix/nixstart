import assert from "node:assert/strict";
import { describe, it } from "node:test";

import continueAfterCompaction, { buildContinuationPrompt } from "../extensions/continue-after-compaction.ts";
import { directGitShipSubcommand } from "../lib/git-interceptor.ts";
import { SimpleFrontmatterCodec } from "../extensions/skill-toggle/src/frontmatter/parser.ts";
import { MinimalFrontmatterPatcher } from "../extensions/skill-toggle/src/frontmatter/patcher.ts";
import { classifyInvocationMode } from "../extensions/skill-toggle/src/inventory/classifier.ts";

describe("Git interception", () => {
	it("recognizes direct shipping commands without confusing ordinary Git operations", () => {
		assert.equal(directGitShipSubcommand("git commit -m test"), "commit");
		assert.equal(directGitShipSubcommand("env FOO=1 git -C repo push origin main"), "push");
		assert.equal(directGitShipSubcommand("git status && echo commit"), undefined);
	});
});

describe("skill invocation toggling", () => {
	const codec = new SimpleFrontmatterCodec();
	const patcher = new MinimalFrontmatterPatcher();

	it("adds and removes only the manual-invocation field", () => {
		const original = "---\nname: demo\ndescription: Demo\n---\nBody\n";
		const manual = patcher.patchInvocationMode(codec.parse(original), "manual-only").newText;
		assert.equal(classifyInvocationMode(codec.parse(manual)), "manual-only");
		assert.match(manual, /name: demo/);

		const automatic = patcher.patchInvocationMode(codec.parse(manual), "agent-invocable").newText;
		assert.equal(automatic, original);
	});
});

describe("post-compaction continuation", () => {
	it("directs persisted sessions to follow the active branch and continue work", () => {
		const prompt = buildContinuationPrompt("/tmp/session.jsonl", "compact-1");
		assert.match(prompt, /parentId links/);
		assert.match(prompt, /Immediately perform the next unfinished step/);
		assert.match(prompt, /\/tmp\/session\.jsonl/);
	});

	it("handles ephemeral sessions without inventing a session path", () => {
		const prompt = buildContinuationPrompt(undefined, "compact-2");
		assert.match(prompt, /ephemeral/);
		assert.doesNotMatch(prompt, /Inspect it directly/);
	});
});

// Building the right prompt is worthless if it is never delivered, delivered
// twice, or delivered after the session is gone. None of those announce
// themselves: the session simply sits there waiting for the user.
describe("post-compaction continuation delivery", () => {
	const fakePi = () => {
		const handlers = new Map<string, (event: any, ctx: any) => void>();
		const sent: Array<{ message: string; options: any }> = [];
		const pi = {
			on(event: string, handler: (event: any, ctx: any) => void) {
				handlers.set(event, handler);
			},
			sendUserMessage(message: string, options: any) {
				sent.push({ message, options });
			},
		};
		const compact = (id: string, sessionFile: string | undefined) =>
			handlers.get("session_compact")?.(
				{ compactionEntry: { id } },
				{ sessionManager: { getSessionFile: () => sessionFile } },
			);
		return { pi, sent, handlers, compact, shutdown: () => handlers.get("session_shutdown")?.({}, {}) };
	};

	const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

	it("delivers exactly one deferred follow-up per compaction", async () => {
		const { pi, sent, compact } = fakePi();
		continueAfterCompaction(pi as any);

		compact("compact-1", "/tmp/session.jsonl");
		assert.equal(sent.length, 0, "delivery must be deferred past the compaction turn");

		await flush();
		assert.equal(sent.length, 1);
		assert.equal(sent[0].options.deliverAs, "followUp");
		assert.match(sent[0].message, /"\/tmp\/session\.jsonl"/);
		assert.match(sent[0].message, /"compact-1"/);

		await flush();
		assert.equal(sent.length, 1, "a single compaction must not resend");
	});

	it("registers for compaction and shutdown rather than firing once", () => {
		const { pi, handlers } = fakePi();
		continueAfterCompaction(pi as any);
		assert.deepEqual([...handlers.keys()].sort(), ["session_compact", "session_shutdown"]);
	});

	it("cancels a pending continuation when the session shuts down first", async () => {
		const { pi, sent, compact, shutdown } = fakePi();
		continueAfterCompaction(pi as any);

		compact("compact-1", "/tmp/session.jsonl");
		shutdown();
		await flush();

		assert.equal(sent.length, 0);
	});
});
