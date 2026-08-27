import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { connectedMcpSummary, copySessionName, tmuxSplitArgs } from "../lib/session-copy.ts";

describe("tmux session copies", () => {
	it("names copies from the session name with an id fallback", () => {
		assert.equal(copySessionName("Auth cleanup", "1234567890"), "Copy of Auth cleanup");
		assert.equal(copySessionName(undefined, "1234567890"), "Copy of 12345678");
	});

	it("creates a detached right-hand split targeted at the originating pane", () => {
		assert.deepEqual(
			tmuxSplitArgs("%7", "/tmp/project with spaces", "/tmp/session file.jsonl", "Copy of auth", "fix it"),
			[
				"split-window", "-h", "-d", "-t", "%7", "-c", "/tmp/project with spaces",
				"-P", "-F", "#{pane_id}", "pi", "--session", "/tmp/session file.jsonl",
				"--name", "Copy of auth", "fix it",
			],
		);
	});
});

describe("connected MCP footer summary", () => {
	it("hides empty state, deduplicates names, and caps at three", () => {
		assert.equal(connectedMcpSummary([]), undefined);
		assert.equal(connectedMcpSummary(["linear", "fathom", "linear"]), "linear fathom");
		assert.equal(
			connectedMcpSummary(["linear", "fathom", "chrome", "github", "slack"]),
			"linear fathom chrome +2 others",
		);
	});
});
