/**
 * Desktop toasts for when pi needs you and you are not looking.
 *
 * A prompt that blocks the agent is worthless if it is sitting on a workspace
 * you are not on. This fires a notification in exactly that case — and stays
 * silent when the pane is on screen, so a question you asked for a second ago
 * does not toast at you.
 *
 *   /notify         toggle
 *   /notify test    fire one now, ignoring focus, to check it works
 *
 * Other extensions request a toast by emitting `notify:attention` on the event
 * bus; the focus check lives here so they do not each reimplement it.
 *
 * See docs/notifications.md — it is the source of truth for this file.
 */

import { spawn, spawnSync } from "node:child_process";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

import { paneVisible } from "../lib/focus.ts";

interface Attention {
	title?: string;
	body?: string;
	urgency?: "low" | "normal" | "critical";
	/** Distinct toasts replace each other per kind rather than stacking. */
	kind?: string;
}

function have(command: string): boolean {
	return spawnSync("command", ["-v", command], { shell: true, stdio: "ignore" }).status === 0;
}

export default function (pi: ExtensionAPI) {
	let enabled = true;
	let sessionName: string | undefined;

	const send = (attention: Attention) => {
		if (!have("notify-send")) return;

		const args = [
			"-a",
			"pi",
			"-u",
			attention.urgency ?? "normal",
			// dunst replaces same-tagged toasts instead of stacking them.
			"-h",
			`string:x-dunst-stack-tag:pi-${attention.kind ?? "general"}`,
			attention.title ?? "pi",
		];
		if (attention.body) args.push(attention.body);

		spawn("notify-send", args, { detached: true, stdio: "ignore" }).unref();
	};

	/** Toast only when the pane is somewhere the user is not looking. */
	const maybeNotify = (attention: Attention) => {
		if (!enabled) return;
		const visibility = paneVisible();
		if (visibility.visible) return;

		const where = visibility.where ? `\n${visibility.where}` : "";
		send({ ...attention, body: `${attention.body ?? ""}${where}`.trim() });
	};

	pi.on("session_start", async (_event, ctx) => {
		sessionName = ctx.sessionManager.getSessionName() ?? undefined;
	});

	// Any extension can ask for attention without knowing about focus or dunst.
	pi.events.on("notify:attention", (data) => {
		maybeNotify((data ?? {}) as Attention);
	});

	// A finished turn is the other moment you want to know about from elsewhere.
	pi.on("agent_settled", async () => {
		maybeNotify({
			title: sessionName ? `pi · ${sessionName}` : "pi",
			body: "Turn finished.",
			urgency: "low",
			kind: "settled",
		});
	});

	pi.registerCommand("notify", {
		description: "Desktop toasts when pi needs you and the pane is not visible (test | on | off)",
		handler: async (args, ctx: ExtensionContext) => {
			const requested = args.trim();

			if (requested === "test") {
				const visibility = paneVisible();
				// Deliberately bypasses the focus gate: the point is to prove the
				// toast path works, and you are by definition looking right now.
				send({
					title: "pi · test",
					body: `Notifications are working.\nPane currently ${visibility.visible ? "visible" : `hidden (${visibility.reason})`}`,
					kind: "test",
				});
				ctx.ui.notify(
					have("notify-send")
						? `Sent. Pane detected as ${visibility.visible ? "visible" : `hidden — ${visibility.reason}`}.`
						: "notify-send is not installed.",
					have("notify-send") ? "info" : "error",
				);
				return;
			}

			if (requested === "on" || requested === "off") {
				enabled = requested === "on";
			} else {
				enabled = !enabled;
			}
			ctx.ui.notify(`Desktop notifications ${enabled ? "on" : "off"}.`, "info");
		},
	});
}
