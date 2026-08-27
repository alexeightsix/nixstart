/**
 * Send-hold behavior driven through a fake ExtensionAPI.
 *
 *   node --experimental-strip-types --test tests/send-hold.test.ts
 *
 * These cover the silent failures that matter: queue loss, lifecycle leaks,
 * extension re-entry, non-TUI interception, and :w! forcing the whole queue.
 */

process.env.PI_SEND_HOLD_MS = "60";

import assert from "node:assert/strict";
import { describe, it } from "node:test";

type Handler = (event: any, ctx: any) => Promise<any>;

interface Harness {
	input: (text: string, options?: { source?: string; images?: any[] }) => Promise<any>;
	command: (name: string, args?: string) => Promise<void>;
	shortcut: (key: string) => Promise<void>;
	fire: (event: string) => Promise<void>;
	emit: (channel: string, data?: unknown) => void;
	sent: string[];
	attempted: string[];
	rawContent: unknown[];
	notes: string[];
	widget: () => string[] | undefined;
	setIdle: (value: boolean) => void;
	setAcknowledge: (value: boolean) => void;
}

async function harness(
	options: { mode?: string; hasUI?: boolean; acknowledge?: boolean; existingSession?: boolean } = {},
): Promise<Harness> {
	const handlers = new Map<string, Handler[]>();
	const bus = new Map<string, ((data: unknown) => void)[]>();
	const commands = new Map<string, (args: string, ctx: any) => Promise<void>>();
	const shortcuts = new Map<string, (ctx: any) => Promise<void> | void>();
	const sent: string[] = [];
	const attempted: string[] = [];
	const rawContent: unknown[] = [];
	const notes: string[] = [];
	let widget: string[] | undefined;
	let idle = true;
	let acknowledge = options.acknowledge ?? true;

	const run = async (event: string, payload: any = {}) => {
		let result: any;
		for (const handler of handlers.get(event) ?? []) {
			result = await handler(payload, ctx);
			if (result?.action === "handled") break;
		}
		return result;
	};

	const pi: any = {
		on: (event: string, handler: Handler) => handlers.set(event, [...(handlers.get(event) ?? []), handler]),
		registerCommand: (name: string, opts: any) => commands.set(name, opts.handler),
		registerShortcut: (key: string, opts: any) => shortcuts.set(key, opts.handler),
		sendUserMessage: (content: string | any[]) => {
			rawContent.push(content);
			const text = typeof content === "string" ? content : content.filter((p) => p.type === "text").map((p) => p.text).join("\n");
			const images = typeof content === "string" ? undefined : content.filter((p) => p.type === "image");
			attempted.push(text);
			if (!acknowledge) return;
			sent.push(text);
			idle = false;
			void run("before_agent_start", { prompt: text, images });
			void run("agent_start", {});
		},
		events: {
			on: (channel: string, handler: (data: unknown) => void) => {
				bus.set(channel, [...(bus.get(channel) ?? []), handler]);
				return () => bus.set(channel, (bus.get(channel) ?? []).filter((candidate) => candidate !== handler));
			},
			emit: (channel: string, data: unknown) => {
				for (const handler of bus.get(channel) ?? []) handler(data);
			},
		},
	};

	const ctx: any = {
		mode: options.mode ?? "tui",
		hasUI: options.hasUI ?? true,
		isIdle: () => idle,
		abort: () => undefined,
		sessionManager: {
			getBranch: () =>
				options.existingSession === false
					? []
					: [{ type: "message", message: { role: "user", content: "earlier prompt" } }],
		},
		ui: {
			notify: (message: string) => notes.push(message),
			setStatus: () => undefined,
			setWidget: (_key: string, content: string[] | undefined) => {
				widget = content;
			},
			theme: { fg: (_c: string, text: string) => text },
		},
	};

	const extension = (await import("../extensions/send-hold.ts")).default;
	extension(pi);
	await run("session_start", { reason: "startup" });

	return {
		input: (text, inputOptions = {}) =>
			run("input", {
				text,
				images: inputOptions.images,
				source: inputOptions.source ?? "interactive",
			}),
		command: async (name, args = "") => {
			await commands.get(name)!(args, ctx);
		},
		shortcut: async (key) => {
			await shortcuts.get(key)!(ctx);
		},
		fire: async (event) => {
			if (event === "agent_settled") idle = true;
			await run(event, event === "session_shutdown" ? { reason: "reload" } : {});
		},
		emit: (channel, data) => pi.events.emit(channel, data),
		sent,
		attempted,
		rawContent,
		notes,
		widget: () => widget,
		setIdle: (value) => {
			idle = value;
		},
		setAcknowledge: (value) => {
			acknowledge = value;
		},
	};
}

const settle = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

describe("send hold queue", () => {
	it("sends the first prompt in a new session immediately, then holds later prompts", async () => {
		const h = await harness({ existingSession: false });
		assert.equal((await h.input("/help")).action, "continue");
		assert.equal((await h.input("first prompt")).action, "continue");
		await h.fire("agent_start");
		await h.fire("agent_settled");
		assert.equal((await h.input("second prompt")).action, "handled");
		assert.deepEqual(h.sent, []);
	});

	it("sends a single held message after the hold", async () => {
		const h = await harness();
		assert.equal((await h.input("first")).action, "handled");
		assert.deepEqual(h.sent, []);
		await settle(150);
		assert.deepEqual(h.sent, ["first"]);
	});

	it("queues a second message instead of replacing the first", async () => {
		const h = await harness();
		await h.input("first");
		await h.input("second");
		await settle(150);
		assert.deepEqual(h.sent, ["first"], "first goes, second waits for the turn");
		await h.fire("agent_settled");
		await settle(100);
		assert.deepEqual(h.sent, ["first", "second"]);
	});

	it("never drops three messages typed in a row", async () => {
		const h = await harness();
		await h.input("a");
		await h.input("b");
		await h.input("c");
		for (let i = 0; i < 3; i++) {
			await settle(100);
			await h.fire("agent_settled");
		}
		assert.deepEqual(h.sent, ["a", "b", "c"]);
	});

	it("does not hold input typed while the agent is working", async () => {
		const h = await harness();
		h.setIdle(false);
		assert.equal((await h.input("steer me")).action, "continue");
		assert.deepEqual(h.sent, []);
	});

	it("never holds slash commands or extension replays", async () => {
		const h = await harness();
		assert.equal((await h.input("/abort")).action, "continue");
		assert.equal((await h.input("released", { source: "extension" })).action, "continue");
	});

	it("/abort drops only the most recent, leaving the rest queued", async () => {
		const h = await harness();
		await h.input("keep");
		await h.input("mistake");
		await h.command("abort");
		await settle(150);
		assert.deepEqual(h.sent, ["keep"]);
	});

	it("/abort all clears the held queue", async () => {
		const h = await harness();
		await h.input("one");
		await h.input("two");
		await h.command("abort", "all");
		await settle(150);
		assert.deepEqual(h.sent, []);
	});

	it(":w! submits its prompt and clears every queued countdown", async () => {
		const h = await harness();
		await h.input("urgent");
		await h.input("also urgent");
		h.emit("send-hold:submit-now");
		assert.equal((await h.input("bang prompt")).action, "handled");
		assert.deepEqual(h.sent, ["urgent"]);
		await h.fire("agent_settled");
		await settle(20);
		assert.deepEqual(h.sent, ["urgent", "also urgent"]);
		await h.fire("agent_settled");
		await settle(20);
		assert.deepEqual(h.sent, ["urgent", "also urgent", "bang prompt"]);
	});

	it("bypasses print, JSON, and RPC modes even though RPC has UI", async () => {
		for (const mode of ["print", "json", "rpc"]) {
			const h = await harness({ mode, hasUI: mode === "rpc" });
			assert.equal((await h.input("x")).action, "continue", mode);
		}
	});

	it("preserves image attachments when a TUI prompt is released", async () => {
		const h = await harness();
		const image = { type: "image", data: "abc", mimeType: "image/png" };
		await h.input("look", { images: [image] });
		await settle(150);
		assert.deepEqual(h.rawContent, [[{ type: "text", text: "look" }, image]]);
	});

	it("cleans up its timer and widget on session shutdown", async () => {
		const h = await harness();
		await h.input("must not leak");
		assert.ok(h.widget());
		await h.fire("session_shutdown");
		assert.equal(h.widget(), undefined);
		await settle(150);
		assert.deepEqual(h.attempted, []);
	});

	it("restores and pauses a release blocked by a hard limit", async () => {
		const h = await harness({ acknowledge: false });
		await h.input("after the cap");
		await settle(150);
		assert.deepEqual(h.attempted, ["after the cap"]);
		assert.deepEqual(h.sent, []);
		h.emit("guardrails:input-blocked", { text: "after the cap", breached: "$5" });
		assert.match(h.widget()?.[0] ?? "", /paused by \/limit/);

		h.setAcknowledge(true);
		h.emit("guardrails:limit-changed", { active: false });
		await settle(100);
		assert.deepEqual(h.sent, ["after the cap"]);
	});

	it("keeps held work queued through a timed pause and resumes it at expiry", async () => {
		const h = await harness();
		await h.input("after the pause");
		h.emit("guardrails:pause-changed", { active: true, until: Date.now() + 60_000 });
		await settle(150);
		assert.deepEqual(h.sent, []);
		assert.match(h.widget()?.[0] ?? "", /paused for/);

		h.emit("guardrails:pause-changed", { active: false });
		await settle(100);
		assert.deepEqual(h.sent, ["after the pause"]);
	});

	it("drops a preflight release when the token-cap decision is cancel", async () => {
		const h = await harness({ acknowledge: false });
		await h.input("cancel this");
		await settle(150);
		h.emit("guardrails:input-cancelled", { text: "cancel this" });
		h.setAcknowledge(true);
		await settle(100);
		assert.deepEqual(h.sent, []);
		assert.equal(h.widget(), undefined);
	});

	it("/abort all is an escape hatch for a release that receives no acknowledgement", async () => {
		const h = await harness({ acknowledge: false });
		await h.input("preflight failed");
		await settle(150);
		assert.ok(h.widget());
		await h.command("abort", "all");
		assert.equal(h.widget(), undefined);
	});

	it("shows that queued work waits for the active turn instead of sticking at 0s", async () => {
		const h = await harness();
		await h.input("first");
		await h.input("second");
		h.emit("send-hold:submit-now");
		await h.input("third");
		await settle(20);
		assert.match(h.widget()?.[0] ?? "", /sending after this turn/);
		await h.command("abort", "all");
	});
});
