export interface PendingQuestions {
	title: string;
	questions: string[];
}

export function normalizeQuestions(
	questions: readonly string[],
	title = "Awaiting your answer",
): PendingQuestions | undefined {
	const normalized = questions.map((question) => question.trim()).filter(Boolean);
	if (normalized.length === 0) return undefined;
	return {
		title: title.trim() || "Awaiting your answer",
		questions: normalized,
	};
}

export function isOrdinaryAnswer(text: string, source: string): boolean {
	const trimmed = text.trim();
	return source !== "extension" && trimmed.length > 0 && !trimmed.startsWith("/");
}

export function questionRows(pending: PendingQuestions): string[] {
	return [pending.title, ...pending.questions.map((question, index) => `  ${index + 1}. ${question}`)];
}
