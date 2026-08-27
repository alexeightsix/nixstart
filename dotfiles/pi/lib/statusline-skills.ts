const SKILL_COMMAND_RE = /^\/skill:([a-z0-9]+(?:-[a-z0-9]+)*)(?:\s|$)/i;

export interface SkillHistoryEntry {
	customType?: string;
	data?: { name?: unknown };
	type?: string;
}

export function skillNameFromCommand(text: string): string | undefined {
	return text.trim().match(SKILL_COMMAND_RE)?.[1]?.toLowerCase();
}

export function skillNameFromReadPath(path: string): string | undefined {
	const segments = path.replaceAll("\\", "/").split("/").filter(Boolean);
	if (segments.at(-1)?.toLowerCase() !== "skill.md") return undefined;
	return segments.at(-2)?.toLowerCase();
}

export function addRecentSkill(
	recentSkills: readonly string[],
	name: string,
): string[] {
	return [...recentSkills.filter((skill) => skill !== name), name];
}

export function recentSkillsFromEntries(
	entries: readonly SkillHistoryEntry[],
	entryType: string,
): string[] {
	let recentSkills: string[] = [];
	for (const entry of entries) {
		if (
			entry.type === "custom" &&
			entry.customType === entryType &&
			typeof entry.data?.name === "string"
		)
			recentSkills = addRecentSkill(recentSkills, entry.data.name);
	}
	return recentSkills;
}

export function formatRecentSkills(recentSkills: readonly string[]): string {
	if (recentSkills.length === 0) return "";
	const visible = recentSkills.slice(-2).join(", ");
	const hidden = Math.max(0, recentSkills.length - 2);
	return hidden > 0 ? `${visible} +${hidden} more` : visible;
}
