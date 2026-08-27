import assert from "node:assert/strict";
import { describe, it } from "node:test";

type Handler = (event: any, ctx: any) => Promise<any>;

async function harness() {
	const handlers = new Map<string, Handler[]>();
	const commands = new Map<string, (args: string, ctx: any) => Promise<void>>();
	const bus = new Map<string, ((data: unknown) => void)[]>();
	const emitted: { channel: string; data: any }[] = [];
	const selections: (string | undefined)[] = [];
	const inputs: (string | undefined)[] = [];
	const notifications: string[] = [];
	const entries: any[] = [];
	const sent: any[] = [];
	let idle = true;
	let selectedModel = { provider: "provider", id: "current" };

	const assistantEntry = {
		type: "message",
		message: {
			role: "assistant",
			usage: { totalTokens: 2, cost: { total: 0.01 } },
		},
	};
	const branch = [assistantEntry];

	const run = async (event: string, payload: any = {}) => {
		let result: any;
		for (const handler of handlers.get(event) ?? []) result = await handler(payload, ctx);
		return result;
	};

	const pi: any = {
		on: (event: string, handler: Handler) => handlers.set(event, [...(handlers.get(event) ?? []), handler]),
		registerCommand: (name: string, options: any) => commands.set(name, options.handler),
		appendEntry: (customType: string, data: unknown) => entries.push({ type: "custom", customType, data }),
		setModel: async (model: any) => {
			selectedModel = model;
			ctx.model = model;
			return true;
		},
		sendUserMessage: async (content: any) => {
			sent.push(content);
			const text = typeof content === "string" ? content : content.find((part: any) => part.type === "text")?.text ?? "";
			await run("input", { text, source: "extension", images: [] });
		},
		events: {
			on: (channel: string, handler: (data: unknown) => void) => {
				bus.set(channel, [...(bus.get(channel) ?? []), handler]);
				return () => undefined;
			},
			emit: (channel: string, data: unknown) => {
				emitted.push({ channel, data });
				for (const handler of bus.get(channel) ?? []) handler(data);
			},
		},
	};

	const ctx: any = {
		mode: "tui",
		isIdle: () => idle,
		model: selectedModel,
		scopedModels: [
			{ model: selectedModel },
			{ model: { provider: "other", id: "model" } },
		],
		sessionManager: {
			getBranch: () => branch,
			getEntries: () => entries,
		},
		shutdown: () => undefined,
		ui: {
			setStatus: () => undefined,
			notify: (message: string) => notifications.push(message),
			select: async () => selections.shift(),
			input: async () => inputs.shift(),
			confirm: async () => false,
			theme: { fg: (_color: string, text: string) => text },
		},
	};

	const extension = (await import("../extensions/guardrails.ts")).default;
	extension(pi);
	await run("session_start", { reason: "startup" });

	return {
		command: async (name: string, args = "") => commands.get(name)!(args, ctx),
		input: (text: string, source = "extension") => run("input", { text, source, images: [] }),
		choose: (...choices: (string | undefined)[]) => selections.push(...choices),
		answer: (...answers: (string | undefined)[]) => inputs.push(...answers),
		emitted,
		entries,
		notifications,
		sent,
		model: () => selectedModel,
		setIdle: (value: boolean) => {
			idle = value;
		},
		shutdown: () => run("session_shutdown", { reason: "quit" }),
	};
}

const latest = (h: Awaited<ReturnType<typeof harness>>, channel: string) =>
	h.emitted.filter((event) => event.channel === channel).at(-1)?.data;

describe("pause guardrail", () => {
	it("offers presets, blocks future releases, and resumes explicitly", async () => {
		const h = await harness();
		h.choose("5 minutes");
		await h.command("pause");
		assert.equal(latest(h, "guardrails:pause-changed").active, true);
		assert.equal((await h.input("queued")).action, "handled");
		assert.equal(latest(h, "guardrails:input-blocked").reason, "pause");

		await h.command("pause", "off");
		assert.equal(latest(h, "guardrails:pause-changed").active, false);
		await h.shutdown();
	});

	it("allows steering to finish the active turn while paused", async () => {
		const h = await harness();
		await h.command("pause", "5m");
		h.setIdle(false);
		assert.equal((await h.input("steer", "interactive")).action, "continue");
		await h.shutdown();
	});
});

describe("token-cap recovery", () => {
	it("pauses and retains a held release for retry", async () => {
		const h = await harness();
		await h.command("limit", "1");
		h.choose("Pause and retry later", "15 minutes");
		assert.equal((await h.input("retry me")).action, "handled");
		assert.equal(latest(h, "guardrails:input-blocked").reason, "pause");
		assert.equal(latest(h, "guardrails:pause-changed").active, true);
		await h.shutdown();
	});

	it("switches model, restarts the allowance, and injects the built-in handoff recipe", async () => {
		const h = await harness();
		await h.command("limit", "1");
		h.choose("Switch model and continue with a handoff", "other/model");
		assert.equal((await h.input("continue the migration")).action, "handled");
		assert.deepEqual(h.model(), { provider: "other", id: "model" });
		assert.equal(latest(h, "guardrails:input-cancelled").text, "continue the migration");
		const takeover = h.sent[0] as string;
		assert.match(takeover, /handoff document/i);
		assert.match(takeover, /continue the migration/);
		assert.equal((await h.input("within the restarted allowance")).action, "continue");
		await h.shutdown();
	});

	it("cancels the retained prompt without retrying it", async () => {
		const h = await harness();
		await h.command("limit", "1");
		h.choose("Cancel this prompt");
		assert.equal((await h.input("drop me")).action, "handled");
		assert.equal(latest(h, "guardrails:input-cancelled").text, "drop me");
		assert.deepEqual(h.sent, []);
		await h.shutdown();
	});
});
