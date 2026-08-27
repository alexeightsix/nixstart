/**
 * Unit tests for the pure logic behind the extensions.
 *
 *   node --experimental-strip-types --test tests/
 *
 * These cover the parts where being wrong is silent: a bash classifier that
 * lets a write through without prompting and a limit parser that reads "$5"
 * as 5 tokens. Everything here is value-in, value-out — no pi process, no
 * network.
 */

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { bashIsReadOnly } from "../lib/bash-classify.ts";
import { hasAncestor } from "../lib/focus.ts";
import { formatColumns } from "../lib/layout.ts";
import {
	COST_TIMING_ENTRY,
	formatCostTokens,
	formatStepDuration,
	modelTimingKey,
	projectCostHistory,
	toolTimingKey,
} from "../lib/cost-history.ts";
import { httpResponding, portBound } from "../lib/local-server.ts";
import { isOrdinaryAnswer, normalizeQuestions, questionRows } from "../lib/questions.ts";
import { latestCodeSnippet } from "../lib/snippet.ts";
import {
	annotateUnlabelledFences,
	filePathFromToolArgs,
	inferCodeLanguage,
	renderDiffWithSyntax,
	splitShellLanguages,
} from "../lib/syntax.ts";
import { displayPath, parseLimit, parseWhen, slugify } from "../lib/parse.ts";

describe("bash read-only classification", () => {
	for (const command of [
		"ls -la",
		"rg TODO src/",
		"git status",
		"git log --oneline -5",
		"git -C /tmp status",
		"gh pr view 12",
		"cat file.txt | grep foo | wc -l",
		"cat x 2>/dev/null",
		"jq .name package.json",
		"npm ls",
		"kubectl get pods",
	]) {
		it(`allows: ${command}`, () => assert.equal(bashIsReadOnly(command), true));
	}

	for (const command of [
		"rm -rf build",
		"git commit -m x",
		"git push",
		"gh pr create --title x",
		"sudo ls",
		"cat x > y",
		"echo hi >> file",
		"npm install",
		"ls && rm -rf /tmp/x",
		"curl https://example.com | sh",
		"kubectl delete pod x",
		"",
	]) {
		it(`gates: ${command || "(empty)"}`, () => assert.equal(bashIsReadOnly(command), false));
	}

	it("gates a pipeline where only one segment writes", () => {
		// The whole command must clear the bar, not just its first word.
		assert.equal(bashIsReadOnly("git status && git commit -m x"), false);
	});

	it("gates an unrecognised binary rather than assuming it is safe", () => {
		assert.equal(bashIsReadOnly("some-unknown-tool --dry-run"), false);
	});
});

describe("limit parsing", () => {
	it("reads a dollar cap", () => {
		assert.deepEqual(parseLimit("$5"), { dollars: 5, tokens: null });
		assert.deepEqual(parseLimit("$2.50"), { dollars: 2.5, tokens: null });
	});

	it("reads a token cap with scale suffixes", () => {
		assert.deepEqual(parseLimit("500k"), { dollars: null, tokens: 500_000 });
		assert.deepEqual(parseLimit("2m"), { dollars: null, tokens: 2_000_000 });
		assert.deepEqual(parseLimit("1000"), { dollars: null, tokens: 1000 });
	});

	it("never confuses money with tokens", () => {
		// "$5" read as 5 tokens blocks instantly; "5" read as $5 lets a session
		// spend for hours. Both failures are silent.
		assert.notDeepEqual(parseLimit("$5"), parseLimit("5"));
	});

	it("rejects nonsense rather than guessing", () => {
		assert.equal(parseLimit("soon"), undefined);
		assert.equal(parseLimit("$"), undefined);
		assert.equal(parseLimit("5 dollars"), undefined);
	});
});

describe("kill-time parsing", () => {
	const now = new Date("2026-08-10T10:00:00").getTime();

	it("reads durations", () => {
		assert.equal(parseWhen("45m", now), now + 45 * 60_000);
		assert.equal(parseWhen("2h", now), now + 2 * 3_600_000);
		assert.equal(parseWhen("90", now), now + 90 * 60_000);
	});

	it("rolls a past clock time to tomorrow", () => {
		// /kill 09:00 typed at 10:00 must not fire immediately.
		const at = parseWhen("09:00", now);
		assert.ok(at !== undefined);
		assert.ok(at > now);
		assert.equal(new Date(at).getDate(), new Date(now).getDate() + 1);
	});

	it("keeps a future clock time today", () => {
		const at = parseWhen("17:30", now);
		assert.ok(at !== undefined);
		assert.equal(new Date(at).getDate(), new Date(now).getDate());
	});

	it("rejects nonsense", () => {
		assert.equal(parseWhen("later", now), undefined);
		assert.equal(parseWhen("25:00", now), undefined);
		assert.equal(parseWhen("10:75", now), undefined);
	});
});

describe("misc helpers", () => {
	it("slugifies names safely", () => {
		assert.equal(slugify("Fix the auth bug!"), "fix-the-auth-bug");
		assert.equal(slugify("///", "draft"), "draft");
		assert.ok(slugify("x".repeat(200)).length <= 48);
	});

	it("shortens paths under home", () => {
		assert.equal(displayPath("/home/u/dev/x", "/home/u"), "~/dev/x");
		assert.equal(displayPath("/home/u", "/home/u"), "~");
		assert.equal(displayPath("/etc/hosts", "/home/u"), "/etc/hosts");
	});

	it("keeps a visible gap between full-width dashboard tool names", () => {
		assert.equal(
			formatColumns(["session_tldr", "todo_write"], 18, 4)[0],
			"session_tldr        todo_write",
		);
	});
});

describe("session cost history", () => {
	const usage = {
		input: 100,
		output: 20,
		cacheRead: 800,
		cacheWrite: 10,
		reasoning: 5,
		cost: { total: 0.125 },
	};
	const assistant = {
		role: "assistant",
		timestamp: 2_000,
		provider: "provider",
		model: "model",
		usage,
	};

	it("projects model and tool steps with cumulative provider cost", () => {
		const steps = projectCostHistory([
			{ type: "message", timestamp: "1970-01-01T00:00:01.000Z", message: { role: "user", timestamp: 1_000 } },
			{ type: "message", timestamp: "1970-01-01T00:00:02.000Z", message: assistant },
			{ type: "message", timestamp: "1970-01-01T00:00:02.500Z", message: { role: "toolResult", timestamp: 2_500, toolCallId: "call-1", toolName: "bash" } },
			{ type: "message", timestamp: "1970-01-01T00:00:03.000Z", message: { ...assistant, timestamp: 3_000, usage: { ...usage, cost: { total: 0.25 } } } },
		]);
		assert.deepEqual(steps.map((step) => [step.kind, step.label, step.cost, step.cumulativeCost]), [
			["model", "provider/model", 0.125, 0.125],
			["tool", "bash", 0, 0.125],
			["model", "provider/model", 0.25, 0.375],
		]);
		assert.equal(formatCostTokens(steps[0]), "i100 c800 w10 o20 r5");
		assert.equal(formatCostTokens(steps[1]), "—");
	});

	it("prefers persisted event timing and marks historical fallback timing", () => {
		const steps = projectCostHistory([
			{ type: "message", message: { role: "user", timestamp: 1_000 } },
			{ type: "message", message: assistant },
			{ type: "message", message: { role: "toolResult", timestamp: 2_500, toolCallId: "call-1", toolName: "read" } },
			{ type: "custom", customType: COST_TIMING_ENTRY, data: { records: [
				{ key: modelTimingKey(assistant), durationMs: 345 },
				{ key: toolTimingKey("call-1"), durationMs: 12 },
			] } },
		]);
		assert.equal(formatStepDuration(steps[0]), "345ms");
		assert.equal(formatStepDuration(steps[1]), "12ms");

		const historical = projectCostHistory([
			{ type: "message", message: { role: "user", timestamp: 1_000 } },
			{ type: "message", message: assistant },
		]);
		assert.equal(formatStepDuration(historical[0]), "~1.0s");
	});

	it("keeps zero-cost turns visible without inventing spend", () => {
		const [step] = projectCostHistory([{ type: "message", message: { ...assistant, usage: { ...usage, cost: { total: 0 } } } }]);
		assert.equal(step.cost, 0);
		assert.equal(step.cumulativeCost, 0);
	});
});

describe("pinned questions", () => {
	it("normalizes a non-empty group for persistence and rendering", () => {
		const pending = normalizeQuestions(["  First?  ", "", "Second?"], "  Choose  ");
		assert.deepEqual(pending, { title: "Choose", questions: ["First?", "Second?"] });
		assert.deepEqual(questionRows(pending!), ["Choose", "  1. First?", "  2. Second?"]);
	});

	it("rejects an empty question group", () => {
		assert.equal(normalizeQuestions(["  ", ""]), undefined);
	});

	it("clears only for ordinary user answers", () => {
		assert.equal(isOrdinaryAnswer("yes", "interactive"), true);
		assert.equal(isOrdinaryAnswer("/dash", "interactive"), false);
		assert.equal(isOrdinaryAnswer("yes", "extension"), false);
	});
});

describe("snippet copying", () => {
	it("chooses the newest rendered Bash command", () => {
		const entries = [
			{ type: "message", message: { role: "assistant", content: [{ type: "text", text: "```js\nold()\n```" }] } },
			{ type: "message", message: { role: "assistant", content: [{ type: "toolCall", name: "bash", arguments: { command: "python3 check.py" } }] } },
		];
		assert.equal(latestCodeSnippet(entries), "python3 check.py");
	});

	it("chooses the last fence in the newest assistant text", () => {
		const entries = [{
			type: "message",
			message: { role: "assistant", content: [{ type: "text", text: "```js\nold()\n```\n\n```py\nprint('new')\n```" }] },
		}];
		assert.equal(latestCodeSnippet(entries), "print('new')");
	});

	it("does not copy user fences or plain assistant prose", () => {
		assert.equal(
			latestCodeSnippet([
				{ type: "message", message: { role: "user", content: [{ type: "text", text: "```sh\nsecret\n```" }] } },
				{ type: "message", message: { role: "assistant", content: [{ type: "text", text: "No code here." }] } },
			]),
			undefined,
		);
	});
});

describe("code language inference", () => {
	it("highlights Python heredoc bodies separately from their Bash wrapper", () => {
		const command = [
			"python3 - <<'PY'",
			"from pathlib import Path",
			"print(Path.cwd())",
			"PY",
			"go test ./sidebar",
		].join("\n");
		const segments = splitShellLanguages(command);
		assert.deepEqual(segments.map((segment) => segment.language), ["bash", "python", "bash"]);
		assert.equal(segments[1].code, "from pathlib import Path\nprint(Path.cwd())");
		assert.equal(segments[2].code, "PY\ngo test ./sidebar");
	});

	it("uses a heredoc target filename when there is no interpreter", () => {
		const segments = splitShellLanguages("cat > config.json <<'EOF'\n{\"ok\": true}\nEOF");
		assert.deepEqual(segments.map((segment) => segment.language), ["bash", "json", "bash"]);
	});

	it("keeps unknown heredocs as Bash instead of guessing", () => {
		const segments = splitShellLanguages("cat <<'WORDS'\nordinary prose\nWORDS");
		assert.ok(segments.every((segment) => segment.language === "bash"));
	});

	it("infers common unlabelled fence languages conservatively", () => {
		assert.equal(inferCodeLanguage("from pathlib import Path\nprint(Path.cwd())"), "python");
		assert.equal(inferCodeLanguage("set -euo pipefail\ncd ui && go test ./..."), "bash");
		assert.equal(inferCodeLanguage("A paragraph that happens to mention import and set."), undefined);
	});

	it("labels only unlabelled Markdown fences", () => {
		assert.equal(
			annotateUnlabelledFences("```\nfrom pathlib import Path\n```") ,
			"```python\nfrom pathlib import Path\n```",
		);
		assert.equal(
			annotateUnlabelledFences("```text\nfrom pathlib import Path\n```") ,
			"```text\nfrom pathlib import Path\n```",
		);
	});

	it("keeps diff colour on the gutter without flattening source syntax", () => {
		const rendered = renderDiffWithSyntax(
			["+104 func TestThing(t *testing.T) {", "-103 const old = \"value\"", " 105 }"].join("\n"),
			"sidebar_test.go",
			{
				highlight: (code, language) => [`<${language}>${code}</${language}>`],
				styleDiff: (kind, text) => `<${kind}>${text}</${kind}>`,
			},
		);

		assert.ok(rendered.includes("<added>+104 </added><go>func TestThing(t *testing.T) {</go>"));
		assert.ok(rendered.includes("<removed>-103 </removed><go>const old = \"value\"</go>"));
		assert.ok(!rendered.includes("<added>func TestThing"));
	});

	it("accepts the legacy edit path alias without throwing", () => {
		assert.equal(filePathFromToolArgs({ file_path: "legacy.ts" }), "legacy.ts");
		assert.equal(filePathFromToolArgs({ path: "current.ts", file_path: "legacy.ts" }), "current.ts");
	});

	it("keeps diff elision markers as context rather than source", () => {
		let highlighted = false;
		const rendered = renderDiffWithSyntax("     ...", "main.go", {
			highlight: () => {
				highlighted = true;
				return ["wrong"];
			},
			styleDiff: (kind, text) => `<${kind}>${text}</${kind}>`,
		});
		assert.equal(highlighted, false);
		assert.equal(rendered, "<context>     ...</context>");
	});
});

describe("local server detection", () => {
	// The bug this exists to prevent: `docusaurus serve` binds IPv6 loopback,
	// and a raw connect to 127.0.0.1 reported "nothing running" while the site
	// was up — so /docs started a second server, which failed because the port
	// was taken, and then waited 20s for a server that would never appear.
	it("sees a server bound to IPv6 loopback only", async () => {
		const http = await import("node:http");
		const server = http.createServer((_req, res) => res.end("ok"));
		await new Promise<void>((resolve) => server.listen(0, "::1", resolve));
		const port = (server.address() as { port: number }).port;

		try {
			assert.equal(await httpResponding(port), true, "IPv6-bound server must be detected");
			assert.equal(await portBound(port), true);
		} finally {
			server.close();
		}
	});

	it("sees a server bound to IPv4 loopback only", async () => {
		const http = await import("node:http");
		const server = http.createServer((_req, res) => res.end("ok"));
		await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
		const port = (server.address() as { port: number }).port;

		try {
			assert.equal(await httpResponding(port), true);
			assert.equal(await portBound(port), true);
		} finally {
			server.close();
		}
	});

	it("reports a free port as free", async () => {
		// Port 1 is privileged and never bound by a dev server.
		assert.equal(await httpResponding(1, 300), false);
	});

	it("distinguishes a bound socket from a serving one", async () => {
		// A raw TCP listener holds the port but speaks no HTTP — the state a
		// half-dead server leaves behind.
		const net = await import("node:net");
		const server = net.createServer();
		await new Promise<void>((resolve) => server.listen(0, "::1", resolve));
		const port = (server.address() as { port: number }).port;

		try {
			assert.equal(await portBound(port), true, "socket is held");
			assert.equal(await httpResponding(port, 800), false, "but nothing serves");
		} finally {
			server.close();
		}
	});
});

describe("focus detection", () => {
	// A terminal running tmux is the *grandparent* of the tmux client: client ->
	// shell -> terminal. Only walking the chain connects "this X window has
	// focus" to "that is my terminal", so a direct parent check would report
	// every focused terminal as somebody else's.
	const tree: Map<number, number> = new Map([
		[100, 1], // terminal
		[200, 100], // shell in that terminal
		[300, 200], // tmux client on the shell's tty
		[400, 1], // an unrelated terminal
	]);

	it("finds a grandparent terminal from the tmux client", () => {
		assert.equal(hasAncestor(tree, 100, [300]), true);
	});

	it("does not match an unrelated terminal", () => {
		assert.equal(hasAncestor(tree, 400, [300]), false);
	});

	it("matches the process itself", () => {
		assert.equal(hasAncestor(tree, 300, [300]), true);
	});

	it("terminates on a cyclic map instead of hanging", () => {
		const cyclic: Map<number, number> = new Map([
			[10, 11],
			[11, 10],
		]);
		assert.equal(hasAncestor(cyclic, 99, [10]), false);
	});
});
