const MODEL_ALIASES: Record<string, string> = {
	"gpt-5.6-sol": "5.6-sol",
	"gpt-5.6-terra": "5.6-terra",
	"gpt-5.5": "5.5",
	"kimi-k3": "k3",
	"deepseek-v4-flash": "v4-flash",
	"nvidia/nemotron-3-ultra-550b-a55b:free": "nemotron",
	"openai/gpt-oss-20b:free": "oss-20b",
};

export function compactModelName(id: string): string {
	return MODEL_ALIASES[id] ?? id;
}

export function thinkingIndicator(level: string | undefined): string {
	return `◇${level || "off"}`;
}

export function permissionIndicator(mode: "all" | "ask" | "read-only"): string {
	if (mode === "all") return "●!";
	if (mode === "ask") return "●?";
	return "●–";
}
