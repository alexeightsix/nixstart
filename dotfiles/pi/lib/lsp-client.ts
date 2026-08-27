import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

import {
	encodeLspMessage,
	formatDiagnostics,
	formatHover,
	formatLocations,
	formatSymbols,
	type JsonRpcMessage,
	LspMessageDecoder,
	resolveSymbolColumn,
	toLspPosition,
	type LspPosition,
} from "./lsp-protocol.ts";
import {
	findWorkspaceRoot,
	resolveLspCommand,
	serverForFile,
	type LspServerConfig,
} from "./lsp-servers.ts";

interface PendingRequest {
	cleanup: () => void;
	reject: (error: Error) => void;
	resolve: (result: unknown) => void;
	timer: NodeJS.Timeout;
}

export type LspAction = "hover" | "definition" | "references" | "symbols" | "diagnostics";

export interface LspQuery {
	action: LspAction;
	column?: number;
	line?: number;
	path: string;
	symbol?: string;
}

interface SpawnOptions {
	cwd: string;
	env: NodeJS.ProcessEnv;
	stdio: ["pipe", "pipe", "pipe"];
}

type SpawnProcess = (
	command: string,
	args: string[],
	options: SpawnOptions,
) => ChildProcessWithoutNullStreams;

export interface LspManagerOptions {
	env?: NodeJS.ProcessEnv;
	requestTimeoutMs?: number;
	spawn?: SpawnProcess;
}

class LspClient {
	private closed = false;
	private diagnostics = new Map<string, unknown[]>();
	private nextId = 1;
	private openedVersions = new Map<string, number>();
	private pending = new Map<number | string, PendingRequest>();
	private process: ChildProcessWithoutNullStreams;
	private ready: Promise<void>;
	private stderr = "";
	private timeoutMs: number;

	constructor(
		command: string,
		config: LspServerConfig,
		root: string,
		env: NodeJS.ProcessEnv,
		timeoutMs: number,
		spawnProcess: SpawnProcess,
	) {
		this.timeoutMs = timeoutMs;
		this.process = spawnProcess(command, config.args, { cwd: root, env, stdio: ["pipe", "pipe", "pipe"] });
		const decoder = new LspMessageDecoder();
		this.process.stdout.on("data", (chunk: Buffer) => {
			try {
				for (const message of decoder.push(chunk)) this.receive(message);
			} catch (error) {
				this.closed = true;
				this.failAll(error instanceof Error ? error : new Error(String(error)));
				this.process.kill("SIGTERM");
			}
		});
		this.process.stderr.on("data", (chunk: Buffer) => {
			this.stderr = `${this.stderr}${chunk.toString("utf8")}`.slice(-8_000);
		});
		this.process.stdin.on("error", (error) => this.failAll(error));
		this.process.on("error", (error) => this.failAll(error));
		this.process.on("exit", (code, signal) => {
			this.closed = true;
			this.failAll(
				new Error(
					`Language server exited (${signal ?? `code ${code ?? "unknown"}`})${this.stderr.trim() ? `: ${this.stderr.trim()}` : ""}`,
				),
			);
		});
		this.ready = this.initialize(root);
	}

	private async initialize(root: string): Promise<void> {
		await this.request("initialize", {
			processId: process.pid,
			clientInfo: { name: "pi-lsp", version: "1" },
			rootUri: pathToFileURL(root).href,
			capabilities: {
				general: { positionEncodings: ["utf-16"] },
				textDocument: {
					synchronization: {
						didSave: true,
						dynamicRegistration: false,
						willSave: false,
					},
					diagnostic: {},
					documentSymbol: { hierarchicalDocumentSymbolSupport: true },
					hover: { contentFormat: ["markdown", "plaintext"] },
					publishDiagnostics: { relatedInformation: true },
				},
				window: { workDoneProgress: true },
				workspace: { configuration: true, workspaceFolders: true },
			},
			workspaceFolders: [{ uri: pathToFileURL(root).href, name: root.split("/").pop() ?? root }],
		});
		this.notify("initialized", {});
	}

	private receive(message: JsonRpcMessage): void {
		if (message.id !== undefined && !message.method) {
			const pending = this.pending.get(message.id);
			if (!pending) return;
			pending.cleanup();
			this.pending.delete(message.id);
			if (message.error) pending.reject(new Error(`LSP ${message.error.code}: ${message.error.message}`));
			else pending.resolve(message.result);
			return;
		}
		if (message.method === "textDocument/publishDiagnostics") {
			const params = message.params as { uri?: unknown; diagnostics?: unknown } | undefined;
			if (typeof params?.uri === "string" && Array.isArray(params.diagnostics))
				this.diagnostics.set(params.uri, params.diagnostics);
		}
		if (message.id !== undefined && message.method) {
			const params = message.params as { items?: unknown[] } | undefined;
			const result = message.method === "workspace/configuration" ? params?.items?.map(() => null) ?? [] : null;
			this.write({ jsonrpc: "2.0", id: message.id, result });
		}
	}

	private write(message: JsonRpcMessage): void {
		if (this.closed) throw new Error("Language server is closed");
		this.process.stdin.write(encodeLspMessage(message));
	}

	private notify(method: string, params: unknown): void {
		this.write({ jsonrpc: "2.0", method, params });
	}

	private request(method: string, params: unknown, signal?: AbortSignal): Promise<unknown> {
		const id = this.nextId++;
		return new Promise((resolveRequest, reject) => {
			let timer: NodeJS.Timeout;
			const cleanup = () => {
				clearTimeout(timer);
				signal?.removeEventListener("abort", onAbort);
			};
			const onAbort = () => {
				cleanup();
				this.pending.delete(id);
				try {
					this.notify("$/cancelRequest", { id });
				} catch {}
				reject(signal?.reason instanceof Error ? signal.reason : new Error("LSP request aborted"));
			};
			if (signal?.aborted) {
				reject(signal.reason instanceof Error ? signal.reason : new Error("LSP request aborted"));
				return;
			}
			timer = setTimeout(() => {
				this.pending.delete(id);
				signal?.removeEventListener("abort", onAbort);
				try {
					this.notify("$/cancelRequest", { id });
				} catch {}
				reject(new Error(`${method} timed out after ${this.timeoutMs}ms`));
			}, this.timeoutMs);
			signal?.addEventListener("abort", onAbort, { once: true });
			this.pending.set(id, { resolve: resolveRequest, reject, timer, cleanup });
			try {
				this.write({ jsonrpc: "2.0", id, method, params });
			} catch (error) {
				cleanup();
				this.pending.delete(id);
				reject(error);
			}
		});
	}

	private failAll(error: Error): void {
		for (const request of this.pending.values()) {
			request.cleanup();
			request.reject(error);
		}
		this.pending.clear();
	}

	private async refreshDocument(
		path: string,
		languageId: string,
		signal?: AbortSignal,
	): Promise<{ text: string; uri: string }> {
		await this.ready;
		if (signal?.aborted) throw signal.reason ?? new Error("LSP request aborted");
		const uri = pathToFileURL(path).href;
		const text = await readFile(path, { encoding: "utf8", signal });
		const previousVersion = this.openedVersions.get(uri);
		const version = (previousVersion ?? 0) + 1;
		this.openedVersions.set(uri, version);
		if (previousVersion === undefined) {
			this.notify("textDocument/didOpen", { textDocument: { uri, languageId, version, text } });
		} else {
			this.notify("textDocument/didChange", {
				textDocument: { uri, version },
				contentChanges: [{ text }],
			});
		}
		return { text, uri };
	}

	async query(
		query: LspQuery,
		config: LspServerConfig,
		cwd: string,
		signal?: AbortSignal,
	): Promise<string> {
		const { text, uri } = await this.refreshDocument(query.path, config.languageId, signal);
		const textDocument = { uri };
		if (query.action === "symbols")
			return formatSymbols(
				await this.request("textDocument/documentSymbol", { textDocument }, signal),
				cwd,
			);
		if (query.action === "diagnostics") {
			try {
				const result = await this.request("textDocument/diagnostic", { textDocument }, signal);
				return formatDiagnostics(result);
			} catch (error) {
				if (!String(error).includes("-32601")) throw error;
				await new Promise((resolveWait) => setTimeout(resolveWait, 300));
				return formatDiagnostics(this.diagnostics.get(uri) ?? []);
			}
		}
		const column = query.symbol
			? resolveSymbolColumn(text, query.line!, query.symbol)
			: query.column!;
		const position: LspPosition = toLspPosition(query.line!, column);
		if (query.action === "hover")
			return formatHover(
				await this.request("textDocument/hover", { textDocument, position }, signal),
			);
		if (query.action === "definition")
			return formatLocations(
				await this.request("textDocument/definition", { textDocument, position }, signal),
				cwd,
			);
		return formatLocations(
			await this.request(
				"textDocument/references",
				{
					textDocument,
					position,
					context: { includeDeclaration: true },
				},
				signal,
			),
			cwd,
		);
	}

	close(): void {
		if (this.closed) return;
		this.closed = true;
		this.failAll(new Error("Language server stopped"));
		this.process.kill("SIGTERM");
		const process = this.process;
		setTimeout(() => {
			if (process.exitCode === null && process.signalCode === null) process.kill("SIGKILL");
		}, 1_000).unref();
	}
}

export class LspManager {
	private clients = new Map<string, LspClient>();
	private env: NodeJS.ProcessEnv;
	private requestTimeoutMs: number;
	private spawnProcess: SpawnProcess;

	constructor(options: LspManagerOptions = {}) {
		this.env = options.env ?? process.env;
		this.requestTimeoutMs = options.requestTimeoutMs ?? 30_000;
		this.spawnProcess = options.spawn ?? spawn;
	}

	async query(input: LspQuery, cwd: string, signal?: AbortSignal): Promise<string> {
		const path = resolve(cwd, input.path);
		const config = serverForFile(path);
		if (!config) throw new Error(`No configured language server for ${input.path}`);
		if (input.action !== "symbols" && input.action !== "diagnostics") {
			if (!Number.isInteger(input.line) || input.line! < 1)
				throw new Error("line must be a positive integer for this action");
			if (!input.symbol && (!Number.isInteger(input.column) || input.column! < 1))
				throw new Error("symbol or a positive integer column is required for this action");
		}
		const root = findWorkspaceRoot(path, config.rootMarkers, cwd);
		const key = `${config.id}\0${root}`;
		let client = this.clients.get(key);
		if (!client) {
			const command = resolveLspCommand(config.command, this.env);
			if (!command)
				throw new Error(
					`${config.command} is not installed. See the Pi LSP documentation for installation instructions.`,
				);
			client = new LspClient(
				command,
				config,
				root,
				this.env,
				this.requestTimeoutMs,
				this.spawnProcess,
			);
			this.clients.set(key, client);
		}
		try {
			return await client.query({ ...input, path }, config, cwd, signal);
		} catch (error) {
			client.close();
			this.clients.delete(key);
			throw error;
		}
	}

	close(): void {
		for (const client of this.clients.values()) client.close();
		this.clients.clear();
	}
}
