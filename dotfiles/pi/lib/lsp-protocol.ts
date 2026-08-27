import { relative } from "node:path";

export interface JsonRpcMessage {
	id?: number | string;
	jsonrpc: "2.0";
	method?: string;
	params?: unknown;
	result?: unknown;
	error?: { code: number; message: string; data?: unknown };
}

export function encodeLspMessage(message: JsonRpcMessage): Buffer {
	const body = Buffer.from(JSON.stringify(message), "utf8");
	return Buffer.concat([Buffer.from(`Content-Length: ${body.length}\r\n\r\n`, "ascii"), body]);
}

export class LspMessageDecoder {
	private buffer = Buffer.alloc(0);

	push(chunk: Buffer | string): JsonRpcMessage[] {
		this.buffer = Buffer.concat([
			this.buffer,
			typeof chunk === "string" ? Buffer.from(chunk, "utf8") : chunk,
		]);
		const messages: JsonRpcMessage[] = [];
		while (true) {
			const headerEnd = this.buffer.indexOf("\r\n\r\n");
			if (headerEnd < 0) break;
			const header = this.buffer.subarray(0, headerEnd).toString("ascii");
			const lengthMatch = /(?:^|\r\n)Content-Length:\s*(\d+)\s*(?:\r\n|$)/i.exec(header);
			if (!lengthMatch) throw new Error("LSP message is missing Content-Length");
			const length = Number(lengthMatch[1]);
			const bodyStart = headerEnd + 4;
			if (this.buffer.length < bodyStart + length) break;
			const body = this.buffer.subarray(bodyStart, bodyStart + length).toString("utf8");
			this.buffer = this.buffer.subarray(bodyStart + length);
			messages.push(JSON.parse(body) as JsonRpcMessage);
		}
		return messages;
	}
}

export interface LspPosition {
	line: number;
	character: number;
}

export interface LspRange {
	start: LspPosition;
	end: LspPosition;
}

export function toLspPosition(line: number, column: number): LspPosition {
	if (!Number.isInteger(line) || line < 1) throw new Error("line must be a positive integer");
	if (!Number.isInteger(column) || column < 1)
		throw new Error("column must be a positive integer");
	return { line: line - 1, character: column - 1 };
}

export function resolveSymbolColumn(content: string, line: number, selector: string): number {
	if (!Number.isInteger(line) || line < 1) throw new Error("line must be a positive integer");
	const sourceLine = content.split(/\r?\n/)[line - 1];
	if (sourceLine === undefined) throw new Error(`line ${line} is outside the file`);
	const match = /^(.*?)(?:#([1-9]\d*))?$/.exec(selector);
	const symbol = match?.[1]?.trim() ?? "";
	const occurrence = Number(match?.[2] ?? 1);
	if (!symbol) throw new Error("symbol must not be empty");
	const positions = (needle: string, haystack: string): number[] => {
		const found: number[] = [];
		let from = 0;
		while (from <= haystack.length - needle.length) {
			const index = haystack.indexOf(needle, from);
			if (index < 0) break;
			found.push(index);
			from = index + Math.max(needle.length, 1);
		}
		return found;
	};
	const matches = positions(symbol, sourceLine);
	if (matches.length < occurrence)
		throw new Error(`symbol ${JSON.stringify(symbol)} occurrence #${occurrence} was not found on line ${line}`);
	return matches[occurrence - 1] + 1;
}

function displayPosition(position: LspPosition): string {
	return `${position.line + 1}:${position.character + 1}`;
}

function displayRange(range: LspRange): string {
	const start = displayPosition(range.start);
	const end = displayPosition(range.end);
	return start === end ? start : `${start}-${end}`;
}

function uriPath(uri: string): string {
	if (!uri.startsWith("file://")) return uri;
	const url = new URL(uri);
	return decodeURIComponent(url.pathname);
}

function displayFile(uri: string, cwd: string): string {
	const path = uriPath(uri);
	const rel = relative(cwd, path);
	return rel && !rel.startsWith("..") ? rel : path;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
	return value !== null && typeof value === "object" ? (value as Record<string, unknown>) : undefined;
}

function asRange(value: unknown): LspRange | undefined {
	const range = asRecord(value);
	const start = asRecord(range?.start);
	const end = asRecord(range?.end);
	if (
		typeof start?.line !== "number" ||
		typeof start.character !== "number" ||
		typeof end?.line !== "number" ||
		typeof end.character !== "number"
	)
		return undefined;
	return { start: start as unknown as LspPosition, end: end as unknown as LspPosition };
}

function markupText(value: unknown): string {
	if (typeof value === "string") return value;
	if (Array.isArray(value)) return value.map(markupText).filter(Boolean).join("\n\n");
	const record = asRecord(value);
	if (typeof record?.value === "string") return record.value;
	if (typeof record?.language === "string" && typeof record.value === "string")
		return `\`\`\`${record.language}\n${record.value}\n\`\`\``;
	return "";
}

export function formatHover(result: unknown): string {
	const hover = asRecord(result);
	if (!hover) return "No hover information.";
	const text = markupText(hover.contents).trim();
	return text || "No hover information.";
}

export function formatLocations(result: unknown, cwd: string): string {
	const items = result == null ? [] : Array.isArray(result) ? result : [result];
	const lines = items.flatMap((item) => {
		const location = asRecord(item);
		const uri = location?.uri ?? location?.targetUri;
		const range = asRange(location?.range ?? location?.targetSelectionRange ?? location?.targetRange);
		return typeof uri === "string" && range
			? [`${displayFile(uri, cwd)}:${displayRange(range)}`]
			: [];
	});
	return lines.length ? lines.join("\n") : "No locations found.";
}

const SYMBOL_KINDS = [
	"File",
	"Module",
	"Namespace",
	"Package",
	"Class",
	"Method",
	"Property",
	"Field",
	"Constructor",
	"Enum",
	"Interface",
	"Function",
	"Variable",
	"Constant",
	"String",
	"Number",
	"Boolean",
	"Array",
	"Object",
	"Key",
	"Null",
	"EnumMember",
	"Struct",
	"Event",
	"Operator",
	"TypeParameter",
];

export function formatSymbols(result: unknown, cwd: string): string {
	if (!Array.isArray(result) || result.length === 0) return "No symbols found.";
	const lines: string[] = [];
	const visit = (item: unknown, depth: number) => {
		const symbol = asRecord(item);
		if (!symbol || typeof symbol.name !== "string") return;
		const location = asRecord(symbol.location);
		const uri = typeof location?.uri === "string" ? location.uri : undefined;
		const range = asRange(symbol.selectionRange ?? symbol.range ?? location?.range);
		const where = range
			? `${uri ? `${displayFile(uri, cwd)}:` : ""}${displayRange(range)}`
			: "unknown position";
		const kind = typeof symbol.kind === "number" ? (SYMBOL_KINDS[symbol.kind - 1] ?? "Symbol") : "Symbol";
		lines.push(`${"  ".repeat(depth)}${symbol.name} (${kind}) ${where}`);
		if (Array.isArray(symbol.children)) for (const child of symbol.children) visit(child, depth + 1);
	};
	for (const item of result) visit(item, 0);
	return lines.length ? lines.join("\n") : "No symbols found.";
}

const DIAGNOSTIC_SEVERITIES = ["error", "warning", "info", "hint"];

export function formatDiagnostics(result: unknown): string {
	const record = asRecord(result);
	const items = Array.isArray(result) ? result : Array.isArray(record?.items) ? record.items : [];
	const lines = items.flatMap((item) => {
		const diagnostic = asRecord(item);
		const range = asRange(diagnostic?.range);
		if (!diagnostic || typeof diagnostic.message !== "string" || !range) return [];
		const severity =
			typeof diagnostic.severity === "number"
				? (DIAGNOSTIC_SEVERITIES[diagnostic.severity - 1] ?? "diagnostic")
				: "diagnostic";
		const source = typeof diagnostic.source === "string" ? ` ${diagnostic.source}` : "";
		return [`${displayRange(range)} ${severity}${source}: ${diagnostic.message.replace(/\s+/g, " ").trim()}`];
	});
	return lines.length ? lines.join("\n") : "No diagnostics.";
}
