export interface BurnStatus {
	name: string;
	severity: "normal" | "warning" | "blocked";
	usedPercent: number;
}

interface BurnAgent {
	limits?: Array<{
		active?: boolean;
		severity?: string;
		usedPercent?: number;
	}>;
	name?: string;
	status?: string;
}

const PROVIDER_ALIASES: Record<string, string> = {
	Claude: "CC",
	"Claude 2": "CC2",
	Claude2: "CC2",
	OpenCode: "OC",
	Codex: "CX",
};

/** Project healthy providers' most-used active limits, highest usage first. */
export function burnStatusesFromJson(json: string): BurnStatus[] {
	let snapshot: { agents?: BurnAgent[] };
	try {
		snapshot = JSON.parse(json) as { agents?: BurnAgent[] };
	} catch {
		return [];
	}

	const statuses: BurnStatus[] = [];
	for (const agent of snapshot.agents ?? []) {
		if (agent.status !== "ok" || typeof agent.name !== "string") continue;
		const limits = (agent.limits ?? []).filter(
			(limit) => limit.active === true && typeof limit.usedPercent === "number" && Number.isFinite(limit.usedPercent),
		);
		if (limits.length === 0) continue;
		const limit = limits.reduce((highest, candidate) =>
			(candidate.usedPercent ?? 0) > (highest.usedPercent ?? 0) ? candidate : highest,
		);
		statuses.push({
			name: PROVIDER_ALIASES[agent.name] ?? agent.name,
			severity: limit.severity === "blocked" ? "blocked" : limit.severity === "warning" ? "warning" : "normal",
			usedPercent: Math.max(0, Math.min(100, Math.round(limit.usedPercent ?? 0))),
		});
	}
	return statuses.sort((left, right) => right.usedPercent - left.usedPercent);
}

export function burnAliasForPiProvider(provider: string | undefined): string | undefined {
	if (provider === "openai-codex") return "CX";
	if (provider === "opencode-go") return "OC";
	return undefined;
}

export function formatBurnStatus(status: BurnStatus, activeAlias?: string): string {
	const marker = status.name === activeAlias ? "*" : "";
	return `${status.name}${marker} ${status.usedPercent}%`;
}
