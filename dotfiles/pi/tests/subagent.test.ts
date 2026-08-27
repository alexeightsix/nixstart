import assert from "node:assert/strict";
import test from "node:test";

import {
	addSubagentUsage,
	captureSubagentEvent,
	emptySubagentUsage,
	subagentFailed,
	truncateSubagentOutput,
	type SubagentCapture,
} from "../lib/subagent.ts";

function capture(): SubagentCapture {
	return { outputs: [], usage: emptySubagentUsage() };
}

test("captures final assistant text, stop reason, and provider usage", () => {
	const result = capture();
	captureSubagentEvent(result, {
		type: "message_end",
		message: {
			role: "assistant",
			content: [{ type: "text", text: "found it" }],
			stopReason: "stop",
			usage: {
				input: 10,
				output: 2,
				cacheRead: 4,
				cacheWrite: 1,
				totalTokens: 17,
				cost: { input: 1, output: 2, cacheRead: 3, cacheWrite: 4, total: 10 },
			},
		},
	});
	assert.deepEqual(result.outputs, ["found it"]);
	assert.equal(result.stopReason, "stop");
	assert.equal(result.usage.totalTokens, 17);
	assert.equal(result.usage.cost.total, 10);
});

test("ignores non-assistant and malformed stream events", () => {
	const result = capture();
	captureSubagentEvent(result, null);
	captureSubagentEvent(result, { type: "tool_result_end", message: {} });
	captureSubagentEvent(result, { type: "message_end", message: { role: "user", content: [] } });
	assert.deepEqual(result.outputs, []);
	assert.deepEqual(result.usage, emptySubagentUsage());
});

test("aggregates nested model usage", () => {
	const total = emptySubagentUsage();
	addSubagentUsage(total, { input: 2, output: 3, totalTokens: 5, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0.5 } });
	addSubagentUsage(total, { input: 7, cacheRead: 11, totalTokens: 18, cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 1.5 } });
	assert.equal(total.input, 9);
	assert.equal(total.output, 3);
	assert.equal(total.cacheRead, 11);
	assert.equal(total.totalTokens, 23);
	assert.equal(total.cost.total, 2);
});

test("caps model-visible output by UTF-8 bytes", () => {
	const result = truncateSubagentOutput("é".repeat(100), 21);
	const kept = result.split("\n\n[Output truncated:")[0];
	assert.ok(Buffer.byteLength(kept, "utf8") <= 21);
	assert.match(result, /Output truncated/);
});

test("classifies process and provider failures", () => {
	assert.equal(subagentFailed(1, capture()), true);
	const providerError = capture();
	providerError.stopReason = "error";
	assert.equal(subagentFailed(0, providerError), true);
	assert.equal(subagentFailed(0, capture()), false);
});
