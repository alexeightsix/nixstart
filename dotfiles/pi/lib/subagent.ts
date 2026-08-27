export const MAX_SUBAGENT_TASKS = 4;
export const MAX_SUBAGENT_OUTPUT_BYTES = 50 * 1024;

export interface SubagentUsage {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
	cost: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		total: number;
	};
}

export interface SubagentCapture {
	outputs: string[];
	stopReason?: string;
	errorMessage?: string;
	usage: SubagentUsage;
}

export function emptySubagentUsage(): SubagentUsage {
	return {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		totalTokens: 0,
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
	};
}

export function addSubagentUsage(target: SubagentUsage, source: Partial<SubagentUsage> | undefined): void {
	if (!source) return;
	target.input += source.input ?? 0;
	target.output += source.output ?? 0;
	target.cacheRead += source.cacheRead ?? 0;
	target.cacheWrite += source.cacheWrite ?? 0;
	target.totalTokens += source.totalTokens ?? 0;
	const cost = source.cost;
	if (!cost) return;
	target.cost.input += cost.input ?? 0;
	target.cost.output += cost.output ?? 0;
	target.cost.cacheRead += cost.cacheRead ?? 0;
	target.cost.cacheWrite += cost.cacheWrite ?? 0;
	target.cost.total += cost.total ?? 0;
}

export function captureSubagentEvent(capture: SubagentCapture, event: unknown): void {
	if (!event || typeof event !== "object") return;
	const candidate = event as { type?: unknown; message?: unknown };
	if (candidate.type !== "message_end" || !candidate.message || typeof candidate.message !== "object") return;
	const message = candidate.message as {
		role?: unknown;
		content?: unknown;
		stopReason?: unknown;
		errorMessage?: unknown;
		usage?: Partial<SubagentUsage>;
	};
	if (message.role !== "assistant") return;
	if (Array.isArray(message.content)) {
		for (const part of message.content) {
			if (part && typeof part === "object" && (part as { type?: unknown }).type === "text") {
				const text = (part as { text?: unknown }).text;
				if (typeof text === "string" && text.trim()) capture.outputs.push(text);
			}
		}
	}
	if (typeof message.stopReason === "string") capture.stopReason = message.stopReason;
	if (typeof message.errorMessage === "string") capture.errorMessage = message.errorMessage;
	addSubagentUsage(capture.usage, message.usage);
}

export function truncateSubagentOutput(text: string, maxBytes = MAX_SUBAGENT_OUTPUT_BYTES): string {
	const bytes = Buffer.byteLength(text, "utf8");
	if (bytes <= maxBytes) return text;
	let end = Math.min(text.length, maxBytes);
	while (end > 0 && Buffer.byteLength(text.slice(0, end), "utf8") > maxBytes) end--;
	return `${text.slice(0, end)}\n\n[Output truncated: ${bytes - Buffer.byteLength(text.slice(0, end), "utf8")} bytes omitted.]`;
}

export function subagentFailed(exitCode: number, capture: SubagentCapture): boolean {
	return exitCode !== 0 || capture.stopReason === "error" || capture.stopReason === "aborted";
}
