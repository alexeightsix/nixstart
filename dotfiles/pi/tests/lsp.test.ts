import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";

import {
	encodeLspMessage,
	formatDiagnostics,
	formatHover,
	formatLocations,
	formatSymbols,
	LspMessageDecoder,
	resolveSymbolColumn,
	toLspPosition,
} from "../lib/lsp-protocol.ts";
import { findWorkspaceRoot, resolveLspCommand, serverForFile } from "../lib/lsp-servers.ts";

describe("LSP message framing", () => {
	it("decodes a frame split across arbitrary chunks", () => {
		const message = { jsonrpc: "2.0" as const, id: 7, result: { text: "héllo" } };
		const frame = encodeLspMessage(message);
		const decoder = new LspMessageDecoder();
		assert.deepEqual(decoder.push(frame.subarray(0, 9)), []);
		assert.deepEqual(decoder.push(frame.subarray(9, frame.length - 2)), []);
		assert.deepEqual(decoder.push(frame.subarray(frame.length - 2)), [message]);
	});

	it("drains coalesced frames in order", () => {
		const first = { jsonrpc: "2.0" as const, id: 1, result: "one" };
		const second = { jsonrpc: "2.0" as const, method: "ready", params: {} };
		const decoder = new LspMessageDecoder();
		assert.deepEqual(decoder.push(Buffer.concat([encodeLspMessage(first), encodeLspMessage(second)])), [
			first,
			second,
		]);
	});
});

describe("LSP routing", () => {
	it("maps Go and TypeScript-family files to the requested native servers", () => {
		assert.equal(serverForFile("main.go")?.id, "gopls");
		for (const path of ["app.ts", "app.tsx", "app.mts", "app.js", "app.cjs"])
			assert.equal(serverForFile(path)?.id, "tsgo");
		assert.equal(serverForFile("README.md"), undefined);
	});

	it("honors marker priority across enclosing directories", () => {
		const root = mkdtempSync(join(tmpdir(), "pi-lsp-root-"));
		const project = join(root, "project");
		const packageRoot = join(project, "packages", "app");
		const nested = join(packageRoot, "src");
		mkdirSync(nested, { recursive: true });
		writeFileSync(join(project, "tsconfig.json"), "{}");
		writeFileSync(join(packageRoot, "package.json"), "{}");
		assert.equal(
			findWorkspaceRoot(join(nested, "index.ts"), ["tsconfig.json", "package.json"], root),
			project,
		);
	});

	it("resolves executables from PATH and the conventional Go fallback", () => {
		const root = mkdtempSync(join(tmpdir(), "pi-lsp-bin-"));
		const bin = join(root, "bin");
		mkdirSync(bin);
		const tsgo = join(bin, "tsgo");
		writeFileSync(tsgo, "#!/bin/sh\n");
		chmodSync(tsgo, 0o755);
		assert.equal(resolveLspCommand("tsgo", { PATH: bin }), tsgo);

		const goBin = join(root, "go", "bin");
		mkdirSync(goBin, { recursive: true });
		const gopls = join(goBin, "gopls");
		writeFileSync(gopls, "#!/bin/sh\n");
		chmodSync(gopls, 0o755);
		assert.equal(resolveLspCommand("gopls", { PATH: "", HOME: root }), gopls);
	});
});

describe("LSP positions and output", () => {
	it("converts one-based positions and resolves symbol occurrences", () => {
		assert.deepEqual(toLspPosition(3, 5), { line: 2, character: 4 });
		const content = "first\nconst value = value + 1;\n";
		assert.equal(resolveSymbolColumn(content, 2, "value"), 7);
		assert.equal(resolveSymbolColumn(content, 2, "value#2"), 15);
	});

	it("formats hover, locations, symbols, and diagnostics compactly", () => {
		assert.equal(formatHover({ contents: { kind: "markdown", value: "**number**" } }), "**number**");
		assert.equal(
			formatLocations(
				{
					uri: "file:///repo/src/main.ts",
					range: { start: { line: 4, character: 2 }, end: { line: 4, character: 6 } },
				},
				"/repo",
			),
			"src/main.ts:5:3-5:7",
		);
		assert.match(
			formatSymbols(
				[
					{
						name: "run",
						kind: 12,
						selectionRange: { start: { line: 1, character: 0 }, end: { line: 1, character: 3 } },
					},
				],
				"/repo",
			),
			/^run \(Function\) 2:1-2:4$/,
		);
		assert.equal(
			formatDiagnostics({
				items: [
					{
						range: { start: { line: 2, character: 4 }, end: { line: 2, character: 5 } },
						severity: 1,
						source: "tsgo",
						message: "Type mismatch",
					},
				],
			}),
			"3:5-3:6 error tsgo: Type mismatch",
		);
	});
});
