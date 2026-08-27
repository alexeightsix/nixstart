/**
 * Send hold — a prompt waits a few seconds before it goes to the model.
 *
 *   :w!        submit and flush every held message in FIFO order
 *   /abort     discard the most recent held message, or interrupt the running turn
 *   /abort all discard every held message
 *
 * Only idle input from the interactive TUI is held. Mid-turn input belongs to
 * Pi's steering queue; RPC/JSON/print callers need their normal acknowledgement
 * contract and must not lose image attachments.
 *
 * See docs/send-hold.md — it is the source of truth for this file.
 */

import type { ImageContent } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Overridable so tests do not have to wait five seconds per assertion. */
const HOLD_MS = Number(process.env.PI_SEND_HOLD_MS) || 5000;
const TICK_MS = Math.min(250, Math.max(10, Math.floor(HOLD_MS / 10)));

interface Held {
	text: string;
	images?: ImageContent[];
	sendAt: number;
}

export default function (pi: ExtensionAPI) {
	/** FIFO. Order typed is order released. */
	const queue: Held[] = [];
	let releasing: Held | undefined;
	let ticker: ReturnType<typeof setInterval> | undefined;
	let streaming = false;
	let pausedByLimit = false;
	let pausedUntil: number | undefined;
	let bypassNextHold = false;
	let sendNextNow = false;

	/** Bound per session because timer callbacks outlive their event handler. */
	let setStatus: ((key: string, value: string | undefined) => void) | undefined;
	let setWidget: ((key: string, content: string[] | undefined, options?: unknown) => void) | undefined;
	let fg: ((color: string, text: string) => string) | undefined;

	const stopTicker = () => {
		if (!ticker) return;
		clearInterval(ticker);
		ticker = undefined;
	};

	const isTimePaused = () => pausedUntil !== undefined && pausedUntil > Date.now();
	const pauseLeft = () => {
		const minutes = Math.max(1, Math.ceil(((pausedUntil ?? Date.now()) - Date.now()) / 60_000));
		return minutes >= 60 ? `${Math.floor(minutes / 60)}h${String(minutes % 60).padStart(2, "0")}m` : `${minutes}m`;
	};

	const render = () => {
		if (!fg) return;

		const head = releasing ?? queue[0];
		if (!head) {
			setStatus?.("send-hold", undefined);
			setWidget?.("send-hold", undefined);
			return;
		}

		const more = queue.length - (releasing ? 0 : 1);
		const suffix = more > 0 ? ` +${more}` : "";
		let status: string;
		let heading: string;

		if (pausedByLimit) {
			status = `hold paused${suffix}`;
			heading = "⏸ queued — paused by /limit";
		} else if (isTimePaused()) {
			status = `hold paused ${pauseLeft()}${suffix}`;
			heading = `⏸ queued — paused for ${pauseLeft()}`;
		} else if (releasing) {
			status = `hold sending${suffix}`;
			heading = "⏳ queued — sending now";
		} else if (streaming) {
			status = `hold after turn${suffix}`;
			heading = "⏳ queued — sending after this turn";
		} else {
			const left = Math.max(0, Math.ceil((head.sendAt - Date.now()) / 1000));
			status = `hold ${left}s${suffix}`;
			heading = `⏳ queued — sending in ${left}s`;
		}

		setStatus?.("send-hold", fg("warning", status) + fg("dim", "  /abort"));

		const lines = head.text.trim().split("\n");
		const first = lines[0] ?? "";
		const preview = first.length > 72 ? `${first.slice(0, 72)}…` : first;
		const extra = lines.length > 1 ? fg("dim", `  (+${lines.length - 1} more lines)`) : "";
		const pausedHint = pausedByLimit
			? "    raise /limit or /abort"
			: isTimePaused()
				? "    /pause off to resume    /abort to cancel"
				: "    :w! to send now    /abort to cancel";
		const rows = [
			fg(pausedByLimit ? "error" : "warning", heading) + fg("dim", pausedHint),
			fg("dim", `   ${preview}`) + extra,
		];
		if (more > 0) rows.push(fg("dim", `   …and ${more} more queued behind it`));
		setWidget?.("send-hold", rows, { placement: "aboveEditor" });
	};

	const contentFor = (held: Held): string | ({ type: "text"; text: string } | ImageContent)[] =>
		held.images?.length ? [{ type: "text", text: held.text }, ...held.images] : held.text;

	/** Start releasing the oldest due message. Acceptance is acknowledged by before_agent_start. */
	const flush = () => {
		if (pausedByLimit || isTimePaused() || streaming || releasing || queue.length === 0) {
			render();
			return;
		}
		const head = queue[0];
		if (Date.now() < head.sendAt) {
			render();
			return;
		}

		queue.shift();
		releasing = head;
		render();
		try {
			pi.sendUserMessage(contentFor(head));
		} catch {
			// A stale runtime can throw synchronously. Put the prompt back rather
			// than losing it; session_shutdown normally prevents this path.
			queue.unshift(head);
			releasing = undefined;
			render();
		}
	};

	const startTicker = () => {
		if (ticker || isTimePaused()) return;
		ticker = setInterval(flush, TICK_MS);
	};

	// This is the first positive acknowledgement that Pi accepted the released
	// text past input interception, model/auth checks, and compaction preflight.
	pi.on("before_agent_start", async (event) => {
		if (!releasing || event.prompt !== releasing.text) return;
		releasing = undefined;
		streaming = true;
		render();
		if (queue.length === 0) stopTicker();
	});

	pi.on("agent_start", async () => {
		// before_agent_start normally acknowledges our exact text. This backstop
		// prevents a later input-transform extension from jamming the queue merely
		// because the accepted prompt text changed before the turn began.
		releasing = undefined;
		streaming = true;
		render();
		if (queue.length === 0) stopTicker();
	});

	pi.on("agent_settled", async () => {
		streaming = false;
		flush();
	});

	// Guardrails re-check extension-injected releases. If a previous queued turn
	// crossed a hard cap, restore the attempted head and wait for /limit to move.
	const stopGuardBlocked = pi.events.on("guardrails:input-blocked", (data) => {
		const blocked = data as { text?: string; reason?: "limit" | "pause" };
		if (!releasing || blocked.text !== releasing.text) return;
		queue.unshift(releasing);
		releasing = undefined;
		pausedByLimit = blocked.reason !== "pause";
		render();
	});
	const stopGuardCancelled = pi.events.on("guardrails:input-cancelled", (data) => {
		const blocked = data as { text?: string };
		if (!releasing || blocked.text !== releasing.text) return;
		releasing = undefined;
		pausedByLimit = false;
		if (queue.length === 0) stopTicker();
		render();
	});
	const stopLimitChanged = pi.events.on("guardrails:limit-changed", (data) => {
		if ((data as { active?: boolean }).active !== false || !pausedByLimit) return;
		pausedByLimit = false;
		startTicker();
		flush();
	});
	const stopPauseChanged = pi.events.on("guardrails:pause-changed", (data) => {
		const change = data as { active?: boolean; until?: number };
		pausedUntil = change.active ? change.until : undefined;
		if (isTimePaused()) stopTicker();
		else {
			startTicker();
			flush();
		}
		render();
	});
	const stopSendNextNow = pi.events.on("send-hold:submit-now", () => {
		sendNextNow = true;
		for (const held of queue) held.sendAt = 0;
	});

	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return { action: "continue" as const };

		// This is an editor safeguard, not an RPC transport delay. hasUI is also
		// true in RPC mode, so mode is the required distinction.
		if (ctx.mode !== "tui") return { action: "continue" as const };

		const text = event.text;
		// Commands must run immediately.
		if (!text.trim() || text.trimStart().startsWith("/")) {
			return { action: "continue" as const };
		}

		// Mid-turn input is steering. Pi owns that queue and should receive it now.
		if (!ctx.isIdle()) {
			sendNextNow = false;
			return { action: "continue" as const };
		}

		if (sendNextNow) {
			sendNextNow = false;
			for (const held of queue) held.sendAt = 0;
			queue.push({ text, images: event.images, sendAt: 0 });
			startTicker();
			flush();
			return { action: "handled" as const };
		}

		// A new session should begin immediately. Commands, forwards, notes, and
		// steering above do not consume this one-shot ordinary-prompt bypass.
		if (bypassNextHold) {
			bypassNextHold = false;
			return { action: "continue" as const };
		}

		queue.push({ text, images: event.images, sendAt: Date.now() + HOLD_MS });
		startTicker();
		render();
		return { action: "handled" as const };
	});

	pi.registerCommand("abort", {
		description: "Discard the most recent held message, or interrupt the running turn",
		handler: async (args, ctx) => {
			if (args.trim() === "all" && (queue.length > 0 || releasing)) {
				const count = queue.length + (releasing ? 1 : 0);
				queue.length = 0;
				releasing = undefined;
				pausedByLimit = false;
				if (!ctx.isIdle()) ctx.abort();
				stopTicker();
				render();
				ctx.ui.notify(`Aborted ${count} held message${count === 1 ? "" : "s"}.`, "info");
				return;
			}

			if (queue.length > 0) {
				const dropped = queue.pop() as Held;
				if (queue.length === 0 && !releasing) stopTicker();
				if (queue.length === 0) pausedByLimit = false;
				render();
				const preview = dropped.text.trim().split("\n")[0].slice(0, 60);
				const rest = queue.length > 0 ? ` ${queue.length} still queued — /abort all to clear.` : "";
				ctx.ui.notify(`Aborted before sending: "${preview}".${rest}`, "info");
				return;
			}

			if (releasing) {
				ctx.ui.notify("That message is already leaving the hold queue; use /abort all to clear it.", "warning");
				return;
			}
			if (!ctx.isIdle()) {
				ctx.abort();
				ctx.ui.notify("Interrupted. Files already changed are not reverted.", "warning");
				return;
			}
			ctx.ui.notify("Nothing to abort.", "info");
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		queue.length = 0;
		releasing = undefined;
		pausedByLimit = false;
		stopTicker();
		streaming = !ctx.isIdle();
		bypassNextHold = !ctx.sessionManager.getBranch().some(
			(entry: { type: string; message?: { role?: string } }) =>
				entry.type === "message" && entry.message?.role === "user",
		);
		setStatus = ctx.ui.setStatus.bind(ctx.ui);
		setWidget = ctx.ui.setWidget.bind(ctx.ui) as typeof setWidget;
		fg = ctx.ui.theme.fg.bind(ctx.ui.theme) as typeof fg;
		render();
	});

	pi.on("session_shutdown", async () => {
		stopGuardBlocked();
		stopGuardCancelled();
		stopLimitChanged();
		stopPauseChanged();
		stopSendNextNow();
		queue.length = 0;
		releasing = undefined;
		pausedByLimit = false;
		pausedUntil = undefined;
		sendNextNow = false;
		stopTicker();
		setStatus?.("send-hold", undefined);
		setWidget?.("send-hold", undefined);
		setStatus = undefined;
		setWidget = undefined;
		fg = undefined;
	});
}
