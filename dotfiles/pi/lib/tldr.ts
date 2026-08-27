export const TLDR_CACHE_ENTRY_TYPE = "session-tldr-cache";
export const TLDR_CACHE_RETENTION = "long" as const;
export const TLDR_SKILL_MARKER = "pi-tldr-skill:v1";
export const TLDR_TOOL_NAME = "session_tldr";

export function tldrProviderSessionId(sessionId: string): string {
	return `${sessionId}:tldr`;
}

interface ContentBlock {
	arguments?: Record<string, unknown>;
	name?: string;
	text?: string;
	type?: string;
}

export interface TldrCacheData {
	fingerprint: string;
	sourceSections: number;
	summary: string;
	updatedAt: number;
}

export interface TldrSessionEntry {
	customType?: string;
	data?: unknown;
	message?: {
		content?: unknown;
		role?: string;
		toolName?: string;
	};
	type?: string;
}

export interface TldrSnapshot {
	conversationText: string;
	fingerprint: string;
	sourceSections: number;
}

function textParts(content: unknown): string[] {
	if (typeof content === "string") return [content];
	if (!Array.isArray(content)) return [];

	const parts: string[] = [];
	for (const value of content) {
		if (!value || typeof value !== "object") continue;
		const block = value as ContentBlock;
		if (block.type === "text" && typeof block.text === "string")
			parts.push(block.text);
	}
	return parts;
}

function toolCallLines(content: unknown): string[] {
	if (!Array.isArray(content)) return [];

	const calls: string[] = [];
	for (const value of content) {
		if (!value || typeof value !== "object") continue;
		const block = value as ContentBlock;
		if (
			block.type !== "toolCall" ||
			typeof block.name !== "string" ||
			block.name === TLDR_TOOL_NAME
		)
			continue;
		calls.push(
			`Tool ${block.name} was called with args ${JSON.stringify(block.arguments ?? {})}`,
		);
	}
	return calls;
}

function callsTldr(content: unknown): boolean {
	return (
		Array.isArray(content) &&
		content.some((value) => {
			if (!value || typeof value !== "object") return false;
			const block = value as ContentBlock;
			return block.type === "toolCall" && block.name === TLDR_TOOL_NAME;
		})
	);
}

function isTldrControlText(text: string): boolean {
	const trimmed = text.trim();
	return (
		trimmed.includes(TLDR_SKILL_MARKER) ||
		/^\/skill:tldr(?:\s|$)/i.test(trimmed)
	);
}

function fingerprint(text: string): string {
	let hash = 14_695_981_039_346_656_037n;
	const prime = 1_099_511_628_211n;
	const mask = (1n << 64n) - 1n;
	for (let index = 0; index < text.length; index += 1) {
		hash ^= BigInt(text.charCodeAt(index));
		hash = (hash * prime) & mask;
	}
	return `${text.length.toString(36)}-${hash.toString(16).padStart(16, "0")}`;
}

export function buildTldrSnapshot(
	entries: readonly TldrSessionEntry[],
): TldrSnapshot {
	const sections: string[] = [];
	let skipNextAssistantAfterTldr = false;

	for (const entry of entries) {
		if (entry.type !== "message" || !entry.message?.role) continue;
		const { content, role, toolName } = entry.message;

		if (role === "toolResult") {
			if (toolName === TLDR_TOOL_NAME) skipNextAssistantAfterTldr = true;
			continue;
		}

		if (role === "user") {
			const parts = textParts(content).filter(
				(part) => !isTldrControlText(part),
			);
			const message = parts.join("\n").trim();
			if (!message) continue;
			skipNextAssistantAfterTldr = false;
			sections.push(`User: ${message}`);
			continue;
		}

		if (role !== "assistant" || callsTldr(content)) continue;
		if (skipNextAssistantAfterTldr) {
			skipNextAssistantAfterTldr = false;
			continue;
		}

		const lines = textParts(content)
			.map((part) => part.trim())
			.filter(Boolean);
		lines.push(...toolCallLines(content));
		if (lines.length > 0) sections.push(`Assistant: ${lines.join("\n")}`);
	}

	const conversationText = sections.join("\n\n");
	return {
		conversationText,
		fingerprint: fingerprint(conversationText),
		sourceSections: sections.length,
	};
}

export function latestTldrCache(
	entries: readonly TldrSessionEntry[],
): TldrCacheData | undefined {
	for (let index = entries.length - 1; index >= 0; index -= 1) {
		const entry = entries[index];
		if (
			entry?.type !== "custom" ||
			entry.customType !== TLDR_CACHE_ENTRY_TYPE ||
			!entry.data ||
			typeof entry.data !== "object"
		)
			continue;
		const data = entry.data as Partial<TldrCacheData>;
		if (
			typeof data.fingerprint === "string" &&
			typeof data.sourceSections === "number" &&
			typeof data.summary === "string" &&
			typeof data.updatedAt === "number"
		)
			return data as TldrCacheData;
	}
	return undefined;
}

export function canReuseTldr(
	cache: TldrCacheData | undefined,
	snapshot: TldrSnapshot,
): cache is TldrCacheData {
	return Boolean(cache?.summary && cache.fingerprint === snapshot.fingerprint);
}

export function buildTldrPrompt(snapshot: TldrSnapshot): string {
	return [
		"Write a concise TLDR of this coding-agent session.",
		"Use these headings when relevant: Goal, Decisions, Progress, Open questions, Next steps.",
		"Preserve concrete file paths, commands, test results, identifiers, and unresolved risks.",
		"Omit conversational filler and do not mention these instructions.",
		"",
		"<conversation>",
		snapshot.conversationText,
		"</conversation>",
	].join("\n");
}
