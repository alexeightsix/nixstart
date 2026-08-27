/**
 * /gc — session storage, and pruning it.
 *
 * Pi does not garbage-collect sessions. Transcripts, exported HTML, shell logs,
 * and improver conversations accumulate in the agent directory until something
 * removes them. This reports what is there and prunes on request.
 *
 *   /gc              what is on disk, per store, with the oldest entry
 *   /gc 30           delete sessions and logs older than 30 days, after confirming
 *   /gc dry 30       show what /gc 30 would delete, without deleting
 *
 * Notes are never pruned — they are written by hand and are not regenerable.
 *
 * See docs/housekeeping.md — it is the source of truth for this file.
 */

import * as fs from "node:fs";
import * as path from "node:path";

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

function agentDir(): string {
	return process.env.PI_CODING_AGENT_DIR ?? path.join(process.env.HOME ?? "", ".pi/agent");
}

interface Store {
	label: string;
	dir: string;
	/** Files matching this are pruning candidates; everything else is only measured. */
	prunable: RegExp | null;
}

function stores(): Store[] {
	const root = agentDir();
	return [
		{ label: "sessions", dir: path.join(root, "sessions"), prunable: /\.(jsonl|html)$/ },
		{ label: "improve", dir: path.join(root, "improve"), prunable: /\.(jsonl|html|log)$/ },
		{ label: "shell-log", dir: path.join(root, "shell-log"), prunable: /\.log$/ },
		{ label: "notes", dir: path.join(root, "notes"), prunable: null },
		{ label: "packages", dir: path.join(root, "npm"), prunable: null },
	];
}

interface FileInfo {
	file: string;
	bytes: number;
	mtime: number;
}

function walk(dir: string): FileInfo[] {
	const found: FileInfo[] = [];
	let entries: fs.Dirent[];
	try {
		entries = fs.readdirSync(dir, { withFileTypes: true });
	} catch {
		return found;
	}
	for (const entry of entries) {
		const full = path.join(dir, entry.name);
		if (entry.isDirectory()) {
			found.push(...walk(full));
		} else if (entry.isFile()) {
			try {
				const stat = fs.statSync(full);
				found.push({ file: full, bytes: stat.size, mtime: stat.mtimeMs });
			} catch {
				// Vanished between readdir and stat; ignore.
			}
		}
	}
	return found;
}

function fmtBytes(bytes: number): string {
	if (bytes >= 1024 ** 3) return `${(bytes / 1024 ** 3).toFixed(1)}G`;
	if (bytes >= 1024 ** 2) return `${(bytes / 1024 ** 2).toFixed(1)}M`;
	if (bytes >= 1024) return `${(bytes / 1024).toFixed(0)}K`;
	return `${bytes}B`;
}

function ageDays(mtime: number): number {
	return (Date.now() - mtime) / 86_400_000;
}

/** Exported so the dashboard can show the same numbers. */
export function summarize(): { label: string; files: number; bytes: number; oldestDays: number }[] {
	return stores().map((store) => {
		const files = walk(store.dir);
		return {
			label: store.label,
			files: files.length,
			bytes: files.reduce((sum, entry) => sum + entry.bytes, 0),
			oldestDays: files.length === 0 ? 0 : Math.max(...files.map((entry) => ageDays(entry.mtime))),
		};
	});
}

export default function (pi: ExtensionAPI) {
	const report = (ctx: ExtensionContext) => {
		const rows = summarize();
		const total = rows.reduce((sum, row) => sum + row.bytes, 0);
		const width = Math.max(...rows.map((row) => row.label.length));
		const lines = rows.map(
			(row) =>
				`  ${row.label.padEnd(width)}  ${fmtBytes(row.bytes).padStart(6)}  ${String(row.files).padStart(4)} files` +
				(row.files > 0 ? `  oldest ${Math.round(row.oldestDays)}d` : ""),
		);
		ctx.ui.notify(
			[
				`Pi storage in ${agentDir()}`,
				...lines,
				`  ${"total".padEnd(width)}  ${fmtBytes(total).padStart(6)}`,
				"",
				"Pi does not prune on its own. /gc <days> removes sessions and logs older than that.",
			].join("\n"),
			"info",
		);
	};

	pi.registerCommand("gc", {
		description: "Session storage report, or prune older than N days (/gc 30, /gc dry 30)",
		handler: async (args, ctx) => {
			const parts = args.trim().split(/\s+/).filter(Boolean);
			const dry = parts[0] === "dry";
			const days = Number(dry ? parts[1] : parts[0]);

			if (!Number.isFinite(days) || days <= 0) {
				report(ctx);
				return;
			}

			const candidates = stores()
				.filter((store) => store.prunable)
				.flatMap((store) =>
					walk(store.dir).filter(
						(entry) => store.prunable?.test(entry.file) && ageDays(entry.mtime) > days,
					),
				);

			if (candidates.length === 0) {
				ctx.ui.notify(`Nothing older than ${days} days.`, "info");
				return;
			}

			const bytes = candidates.reduce((sum, entry) => sum + entry.bytes, 0);

			if (dry) {
				ctx.ui.notify(
					[
						`Would delete ${candidates.length} files (${fmtBytes(bytes)}) older than ${days} days:`,
						...candidates.slice(0, 20).map((entry) => `  ${path.basename(entry.file)}`),
						candidates.length > 20 ? `  …and ${candidates.length - 20} more` : "",
					]
						.filter(Boolean)
						.join("\n"),
					"info",
				);
				return;
			}

			const confirmed = await ctx.ui.confirm(
				`Delete ${candidates.length} files (${fmtBytes(bytes)}) older than ${days} days?`,
				"Session transcripts and logs. Notes and installed packages are not touched. This cannot be undone.",
			);
			if (!confirmed) {
				ctx.ui.notify("Nothing deleted.", "info");
				return;
			}

			let removed = 0;
			for (const entry of candidates) {
				try {
					fs.unlinkSync(entry.file);
					removed += 1;
				} catch {
					// Locked or already gone; skip it.
				}
			}
			ctx.ui.notify(`Deleted ${removed} files, freed ${fmtBytes(bytes)}.`, "info");
		},
	});
}
