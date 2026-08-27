/**
 * /docs — open the documentation in Chrome.
 *
 *   /docs           open http://localhost:3565/changelog
 *   /docs guard     jump straight to a page
 *   /docs stop      stop the local server
 *
 * The docs are the source of truth for this configuration, so reaching them has
 * to be one keystroke rather than a reminder to go and find them.
 *
 * Entirely local: it serves the built site and opens a browser. No model is
 * involved, nothing is billed, and it works with no network.
 *
 * See docs/docs-command.md — it is the source of truth for this file.
 */

import { spawn, spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";

import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

import { httpResponding, portBound, waitForHttp } from "../lib/local-server.ts";

const PORT = 3565;
const CONFIG_DIR = path.join(process.env.HOME ?? "", "kickstart/dotfiles/pi");
const DOCS_DIR = path.join(CONFIG_DIR, "docs");

function browser(): string | undefined {
	for (const candidate of ["google-chrome", "google-chrome-stable", "chromium", "xdg-open"]) {
		if (spawnSync("command", ["-v", candidate], { shell: true, stdio: "ignore" }).status === 0) {
			return candidate;
		}
	}
	return undefined;
}

/** Match a doc page by name so `/docs guard` lands on the right page. */
function resolvePage(query: string): string | undefined {
	const wanted = query.trim().toLowerCase().replace(/\s+/g, "-");
	if (!wanted) return "";

	let pages: string[];
	try {
		pages = fs
			.readdirSync(path.join(DOCS_DIR, "docs"))
			.filter((name) => name.endsWith(".md"))
			.map((name) => name.replace(/\.md$/, ""));
	} catch {
		return undefined;
	}

	// intro is served at the root.
	const exact = pages.find((page) => page === wanted);
	if (exact) return exact === "intro" ? "" : exact;

	const partial = pages.find((page) => page.includes(wanted));
	return partial ? (partial === "intro" ? "" : partial) : undefined;
}

export default function (pi: ExtensionAPI) {
	let server: ReturnType<typeof spawn> | undefined;

	const startServer = async (ctx: ExtensionCommandContext): Promise<boolean> => {
		if (await httpResponding(PORT)) return true;

		// Bound but not answering: a previous server died holding the socket, or
		// something unrelated has the port. Starting another would fail with
		// "already running" and then time out waiting for it, so say so instead.
		if (await portBound(PORT)) {
			ctx.ui.notify(
				`Port ${PORT} is held by something that is not serving the docs. Run /docs stop, then try again.`,
				"error",
			);
			return false;
		}

		if (!fs.existsSync(path.join(DOCS_DIR, "build"))) {
			ctx.ui.notify("Docs have not been built yet — building, this takes a moment…", "info");
			const built = spawnSync("npm", ["run", "build"], { cwd: DOCS_DIR, stdio: "ignore" });
			if (built.status !== 0) {
				ctx.ui.notify("Docs build failed. Run `npm run build` in docs/ to see why.", "error");
				return false;
			}
		}

		// Detached so the docs outlive this pi session; killing pi should not
		// close the tab you were reading.
		server = spawn("npm", ["run", "serve", "--", "--port", String(PORT), "--no-open"], {
			cwd: DOCS_DIR,
			detached: true,
			stdio: "ignore",
		});
		server.unref();

		if (!(await waitForHttp(PORT, 20_000))) {
			ctx.ui.notify(
				`Docs server did not come up on port ${PORT}. Try \`npm run serve\` in ${DOCS_DIR} to see why.`,
				"error",
			);
			return false;
		}
		return true;
	};

	pi.registerCommand("docs", {
		description: "Open the configuration docs in Chrome (/docs <page>, /docs stop)",
		handler: async (args, ctx) => {
			const requested = args.trim();

			if (requested === "stop") {
				if (!(await portBound(PORT))) {
					ctx.ui.notify("Docs server is not running.", "info");
					return;
				}
				// Started detached, so find it by port rather than by handle.
				spawnSync("bash", ["-c", `fuser -k ${PORT}/tcp`], { stdio: "ignore" });
				server = undefined;
				ctx.ui.notify("Docs server stopped.", "info");
				return;
			}

			let page = "changelog";
			if (requested) {
				const resolved = resolvePage(requested);
				if (resolved === undefined) {
					ctx.ui.notify(`No docs page matches "${requested}".`, "warning");
					return;
				}
				page = resolved;
			}

			if (!(await startServer(ctx))) return;

			const url = `http://localhost:${PORT}/${page}`;
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
