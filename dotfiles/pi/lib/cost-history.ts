export const COST_TIMING_ENTRY = "cost-history-timing";

export interface CostTimingRecord {
	key: string;
	durationMs: number;
}

export interface CostStep {
	index: number;
	at: number;
	kind: "model" | "tool";
	label: string;
	durationMs: number;
	estimatedDuration: boolean;
	input: number;
	cacheRead: number;
	cacheWrite: number;
	output: number;
	reasoning: number;
	cost: number;
	cumulativeCost: number;
	isError: boolean;
}

interface UsageLike {
	input?: number;
	output?: number;
	cacheRead?: number;
	cacheWrite?: number;
	reasoning?: number;
	cost?: { total?: number };
}

interface MessageLike {
	role?: string;
	timestamp?: number;
	provider?: string;
	model?: string;
	toolCallId?: string;
	toolName?: string;
	isError?: boolean;
	usage?: UsageLike;
}

interface EntryLike {
	type?: string;
	timestamp?: string;
	customType?: string;
	data?: { records?: CostTimingRecord[] };
	message?: MessageLike;
}

export function modelTimingKey(message: { timestamp?: number; provider?: string; model?: string }): string {
	return `model:${message.timestamp ?? 0}:${message.provider ?? ""}:${message.model ?? ""}`;
}

export function toolTimingKey(toolCallId: string): string {
	return `tool:${toolCallId}`;
}

function timestampOf(entry: EntryLike): number {
	const messageTimestamp = entry.message?.timestamp;
	if (typeof messageTimestamp === "number") return messageTimestamp;
	const parsed = entry.timestamp ? Date.parse(entry.timestamp) : Number.NaN;
	return Number.isFinite(parsed) ? parsed : 0;
}

/** Build the branch's chronological billable-model and local-tool history. */
export function projectCostHistory(entries: readonly EntryLike[]): CostStep[] {
	const timings = new Map<string, number>();
	for (const entry of entries) {
		if (entry.type !== "custom" || entry.customType !== COST_TIMING_ENTRY) continue;
		for (const record of entry.data?.records ?? []) {
			if (record.key && Number.isFinite(record.durationMs)) {
				timings.set(record.key, Math.max(0, record.durationMs));
			}
		}
	}

	const steps: CostStep[] = [];
	let previousMessageAt: number | undefined;
	let cumulativeCost = 0;

	for (const entry of entries) {
		if (entry.type !== "message" || !entry.message) continue;
		const message = entry.message;
		const at = timestampOf(entry);
		const estimated = Math.max(0, previousMessageAt === undefined ? 0 : at - previousMessageAt);

		if (message.role === "assistant" && message.usage) {
			const exact = timings.get(modelTimingKey(message));
			const cost = message.usage.cost?.total ?? 0;
			cumulativeCost += cost;
			steps.push({
				index: steps.length + 1,
				at,
				kind: "model",
				label: `${message.provider ?? "unknown"}/${message.model ?? "unknown"}`,
				durationMs: exact ?? estimated,
				estimatedDuration: exact === undefined,
				input: message.usage.input ?? 0,
				cacheRead: message.usage.cacheRead ?? 0,
				cacheWrite: message.usage.cacheWrite ?? 0,
				output: message.usage.output ?? 0,
				reasoning: message.usage.reasoning ?? 0,
				cost,
				cumulativeCost,
				isError: false,
			});
		} else if (message.role === "toolResult" && message.toolCallId) {
			const exact = timings.get(toolTimingKey(message.toolCallId));
			steps.push({
				index: steps.length + 1,
				at,
				kind: "tool",
				label: message.toolName ?? "unknown",
				durationMs: exact ?? estimated,
				estimatedDuration: exact === undefined,
				input: 0,
				cacheRead: 0,
				cacheWrite: 0,
				output: 0,
				reasoning: 0,
				cost: 0,
				cumulativeCost,
				isError: message.isError ?? false,
			});
		}

		previousMessageAt = at;
	}
	return steps;
}

export function formatCostTokens(step: CostStep): string {
	if (step.kind === "tool") return "—";
	const fmt = (value: number) => {
		if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(2)}M`;
		if (value >= 1000) return `${(value / 1000).toFixed(1)}k`;
		return `${value}`;
	};
	const parts = [`i${fmt(step.input)}`];
	if (step.cacheRead > 0) parts.push(`c${fmt(step.cacheRead)}`);
	if (step.cacheWrite > 0) parts.push(`w${fmt(step.cacheWrite)}`);
	parts.push(`o${fmt(step.output)}`);
	if (step.reasoning > 0) parts.push(`r${fmt(step.reasoning)}`);
	return parts.join(" ");
}

export function formatStepDuration(step: CostStep): string {
	const prefix = step.estimatedDuration ? "~" : "";
	if (step.durationMs < 1000) return `${prefix}${Math.round(step.durationMs)}ms`;
	if (step.durationMs < 60_000) return `${prefix}${(step.durationMs / 1000).toFixed(1)}s`;
	return `${prefix}${Math.floor(step.durationMs / 60_000)}m${Math.round((step.durationMs % 60_000) / 1000)}s`;
}
