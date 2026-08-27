/**
 * /docs — open this project's documentation in a browser.
 *
 *   /docs           open http://localhost:3565/changelog
 *   /docs <page>    jump to a page by loose name match
 *   /docs stop      stop the local server
 *
 * Portable: drop into `.pi/extensions/docs.ts` in any project that has a
 * Docusaurus site at `docs/`. Finds the project root by walking up for that
 * directory, serves the shared local-docs port, and opens the project's
 * changelog by default.
 *
 * Entirely local — no model call, nothing billed, works offline.
 */

import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as net from "node:net";
import * as path from "node:path";

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const PORT = 3565;

/** Walk up from cwd for a directory containing a Docusaurus site. */
function findDocsDir(from: string): string | undefined {
	let dir = path.resolve(from);
	for (let depth = 0; depth < 8; depth++) {
		const candidate = path.join(dir, "docs");
		if (fs.existsSync(path.join(candidate, "docusaurus.config.ts")) ||
			fs.existsSync(path.join(candidate, "docusaurus.config.js"))) {
			return candidate;
		}
		const parent = path.dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return undefined;
}

/**
 * Ask over HTTP, not with a raw socket.
 *
 * A dev server may bind IPv6 loopback only, in which case connecting to
 * 127.0.0.1 reports "nothing running" while the site is up — and the caller
 * then starts a second server that fails because the port is taken. `fetch`
 * resolves both address families, and a response also proves the server is
 * alive rather than a socket held open by a dead process.
 */
async function httpResponding(port: number, timeoutMs = 1500): Promise<boolean> {
	try {
		const response = await fetch(`http://localhost:${port}/`, { signal: AbortSignal.timeout(timeoutMs) });
		return response.ok;
	} catch {
		return false;
	}
}

/** Whether anything holds the port, responding or not. Both families. */
function portBound(port: number, timeoutMs = 700): Promise<boolean> {
	return new Promise((resolve) => {
		let settled = false;
		const done = (bound: boolean) => {
			if (!settled) {
				settled = true;
				resolve(bound);
			}
		};
		for (const host of ["127.0.0.1", "::1"]) {
			const socket = net.connect({ port, host });
			socket.setTimeout(timeoutMs);
			socket.on("connect", () => {
				socket.destroy();
				done(true);
			});
			socket.on("timeout", () => socket.destroy());
			socket.on("error", () => undefined);
		}
		setTimeout(() => done(false), timeoutMs);
	});
}

async function waitForHttp(port: number, timeoutMs: number): Promise<boolean> {
	const deadline = Date.now() + timeoutMs;
	while (Date.now() < deadline) {
		if (await httpResponding(port)) return true;
		await new Promise((resolve) => setTimeout(resolve, 300));
	}
	return false;
}

function browser(): string | undefined {
	for (const candidate of ["google-chrome", "google-chrome-stable", "chromium", "firefox", "open", "xdg-open"]) {
		if (spawnSync("command", ["-v", candidate], { shell: true, stdio: "ignore" }).status === 0) {
			return candidate;
		}
	}
	return undefined;
}

function resolvePage(docsDir: string, query: string): string | undefined {
	const wanted = query.trim().toLowerCase().replace(/\s+/g, "-");
	if (!wanted) return "";

	let pages: string[];
	try {
		pages = fs
			.readdirSync(path.join(docsDir, "docs"))
			.filter((name) => /\.mdx?$/.test(name))
			.map((name) => name.replace(/\.mdx?$/, ""));
	} catch {
		return undefined;
	}

	const exact = pages.find((page) => page === wanted);
	if (exact) return exact === "intro" ? "" : exact;
	const partial = pages.find((page) => page.includes(wanted));
	return partial ? (partial === "intro" ? "" : partial) : undefined;
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("docs", {
		description: "Open this project's docs in a browser (/docs <page>, /docs stop)",
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			const docsDir = findDocsDir(ctx.cwd);
			if (!docsDir) {
				ctx.ui.notify("No Docusaurus site found in docs/ from here upward.", "error");
				return;
			}
			const port = PORT;
			const requested = args.trim();

			if (requested === "stop") {
				if (!(await portBound(port))) {
					ctx.ui.notify("Docs server is not running.", "info");
					return;
				}
				spawnSync("bash", ["-c", `fuser -k ${port}/tcp`], { stdio: "ignore" });
				ctx.ui.notify("Docs server stopped.", "info");
				return;
			}

			let page = "changelog";
			if (requested) {
				const resolved = resolvePage(docsDir, requested);
				if (resolved === undefined) {
					ctx.ui.notify(`No docs page matches "${requested}".`, "warning");
					return;
				}
				page = resolved;
			}

			if (!(await httpResponding(port))) {
				if (await portBound(port)) {
					ctx.ui.notify(`Port ${port} is held by something not serving the docs. /docs stop, then retry.`, "error");
					return;
				}
				if (!fs.existsSync(path.join(docsDir, "build"))) {
					ctx.ui.notify("Building the docs, one moment…", "info");
					if (spawnSync("npm", ["run", "build"], { cwd: docsDir, stdio: "ignore" }).status !== 0) {
						ctx.ui.notify("Docs build failed. Run `npm run build` in docs/ to see why.", "error");
						return;
					}
				}
				// Detached so the docs outlive this session.
				spawn("npm", ["run", "serve", "--", "--port", String(port), "--no-open"], {
					cwd: docsDir,
					detached: true,
					stdio: "ignore",
				}).unref();

				if (!(await waitForHttp(port, 20_000))) {
					ctx.ui.notify(`Docs server did not come up on port ${port}.`, "error");
					return;
				}
			}

			const url = `http://localhost:${port}/${page}`;
			const open = browser();
			if (!open) {
				ctx.ui.notify(`No browser found. Docs are at ${url}`, "warning");
				return;
			}
			spawn(open, [url], { detached: true, stdio: "ignore" }).unref();
			ctx.ui.notify(`Opened ${url}`, "info");
		},
	});
}
