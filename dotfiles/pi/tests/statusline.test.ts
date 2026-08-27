// @ts-ignore -- These built-ins are available in the Node runtime used by the test command.
import assert from "node:assert/strict";
// @ts-ignore -- These built-ins are available in the Node runtime used by the test command.
import { describe, it } from "node:test";

import { burnAliasForPiProvider, burnStatusesFromJson, formatBurnStatus } from "../lib/burn-status.ts";
import { formatUsageIcon, leftExtensionStatuses, STATUS_ICONS } from "../lib/statusline-layout.ts";
import {
	addRecentSkill,
	formatRecentSkills,
	recentSkillsFromEntries,
	skillNameFromCommand,
	skillNameFromReadPath,
} from "../lib/statusline-skills.ts";
import { compactModelName, permissionIndicator, thinkingIndicator } from "../lib/statusline-model.ts";

describe("statusline skill history", () => {
	it("recognizes successful skill reads and explicit skill commands", () => {
		assert.equal(
			skillNameFromReadPath("/home/alex/.agents/skills/code-review/SKILL.md"),
			"code-review",
		);
		assert.equal(skillNameFromReadPath("/repo/README.md"), undefined);
		assert.equal(skillNameFromCommand(" /skill:tdd integration tests"), "tdd");
		assert.equal(skillNameFromCommand("/skills"), undefined);
	});

	it("keeps unique recency and summarizes the two newest for the dashboard", () => {
		let recent: string[] = [];
		for (const name of ["tdd", "demo", "research", "tdd"])
			recent = addRecentSkill(recent, name);
		assert.deepEqual(recent, ["demo", "research", "tdd"]);
		assert.equal(formatRecentSkills(recent), "research, tdd +1 more");
	});

	it("restores recency from session entries and ignores unrelated state", () => {
		assert.deepEqual(
			recentSkillsFromEntries(
				[
					{ type: "custom", customType: "other", data: { name: "ignored" } },
					{ type: "custom", customType: "statusline-skill-loaded", data: { name: "tdd" } },
					{ type: "custom", customType: "statusline-skill-loaded", data: { name: "demo" } },
					{ type: "custom", customType: "statusline-skill-loaded", data: { name: "tdd" } },
				],
				"statusline-skill-loaded",
			),
			["demo", "tdd"],
		);
	});
});

describe("statusline compact labels", () => {
	it("uses compact symbols with breathing room before their values", () => {
		assert.deepEqual(STATUS_ICONS, { cache: "↺", context: "◫" });
		assert.equal(formatUsageIcon("↺", "93%"), "↺ 93%");
		assert.equal(formatUsageIcon("◫", "20%/272k"), "◫ 20%/272k");
	});

	it("makes permission and thinking state decipherable", () => {
		assert.equal(permissionIndicator("all"), "●!");
		assert.equal(permissionIndicator("ask"), "●?");
		assert.equal(permissionIndicator("read-only"), "●–");
		assert.equal(thinkingIndicator("high"), "◇high");
		assert.equal(thinkingIndicator(undefined), "◇off");
	});

	it("aliases every configured model and preserves unknown ids", () => {
		assert.deepEqual(
			[
				"gpt-5.6-sol",
				"gpt-5.6-terra",
				"gpt-5.5",
				"kimi-k3",
				"deepseek-v4-flash",
				"nvidia/nemotron-3-ultra-550b-a55b:free",
				"openai/gpt-oss-20b:free",
			].map(compactModelName),
			["5.6-sol", "5.6-terra", "5.5", "k3", "v4-flash", "nemotron", "oss-20b"],
		);
		assert.equal(compactModelName("unknown/model"), "unknown/model");
	});
});

describe("statusline burn usage", () => {
	const snapshot = JSON.stringify({ agents: [
		{ name: "Claude", status: "ok", limits: [
			{ active: true, usedPercent: 21, severity: "normal" },
		] },
		{ name: "Claude 2", status: "ok", limits: [
			{ active: true, usedPercent: 20, severity: "normal" },
		] },
		{ name: "Codex", status: "ok", spend: { amountUsd: null }, limits: [
			{ active: true, usedPercent: 76, severity: "normal" },
			{ active: true, usedPercent: 12, severity: "normal" },
		] },
		{ name: "OpenCode", status: "ok", spend: { amountUsd: 31.535 }, limits: [
			{ active: true, usedPercent: 100, severity: "blocked" },
		] },
	] });

	it("aliases providers and orders their most-used active limits by usage", () => {
		const statuses = burnStatusesFromJson(snapshot);
		assert.deepEqual(statuses.map((status) => formatBurnStatus(status)), ["OC 100%", "CX 76%", "CC 21%", "CC2 20%"]);
		assert.equal(statuses[0]?.severity, "blocked");
	});

	it("marks only the Burn provider related to the active Pi model", () => {
		const statuses = burnStatusesFromJson(snapshot);
		const codex = burnAliasForPiProvider("openai-codex");
		assert.deepEqual(statuses.map((status) => formatBurnStatus(status, codex)), ["OC 100%", "CX* 76%", "CC 21%", "CC2 20%"]);
		assert.equal(burnAliasForPiProvider("opencode-go"), "OC");
		assert.equal(burnAliasForPiProvider("openrouter"), undefined);
	});

	it("quietly omits malformed and unhealthy snapshots", () => {
		assert.deepEqual(burnStatusesFromJson("not json"), []);
		assert.deepEqual(burnStatusesFromJson('{"agents":[{"name":"Codex","status":"error"}]}'), []);
	});
});

describe("statusline extension filtering", () => {
	it("keeps actionable statuses and removes separately rendered or omitted state", () => {
		const statuses = new Map([
			["permission-mode", "ask"],
			["held-send", "hold 3s"],
			["lsp", "LSP ✓"],
			["mcp", "MCP 2/5"],
		]);
		assert.deepEqual(leftExtensionStatuses(statuses), ["hold 3s"]);
	});
});
