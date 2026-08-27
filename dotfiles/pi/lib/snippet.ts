interface ContentBlock {
	type?: string;
	text?: string;
	name?: string;
	arguments?: Record<string, unknown>;
}

interface TranscriptEntry {
	type?: string;
	message?: {
		role?: string;
		content?: string | ContentBlock[];
	};
}

function lastFence(text: string): string | undefined {
	const matches = [...text.matchAll(/(?:^|\n)[ \t]*(`{3,}|~{3,})[^\n]*\n([\s\S]*?)\n[ \t]*\1(?=\n|$)/g)];
	return matches.at(-1)?.[2];
}

/** Return the newest Bash tool command or assistant fenced code block. */
export function latestCodeSnippet(entries: readonly TranscriptEntry[]): string | undefined {
	for (let entryIndex = entries.length - 1; entryIndex >= 0; entryIndex -= 1) {
		const message = entries[entryIndex]?.message;
		if (message?.role !== "assistant" || !Array.isArray(message.content)) continue;
		for (let blockIndex = message.content.length - 1; blockIndex >= 0; blockIndex -= 1) {
			const block = message.content[blockIndex];
			if (block.type === "toolCall" && block.name === "bash") {
				const command = block.arguments?.command;
				if (typeof command === "string" && command.length > 0) return command;
			}
			if (block.type === "text" && typeof block.text === "string") {
				const fenced = lastFence(block.text);
				if (fenced !== undefined) return fenced;
			}
		}
	}
	return undefined;
}
