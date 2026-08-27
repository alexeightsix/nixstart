export const STATUS_ICONS = {
	cache: "↺",
	context: "◫",
} as const;

export function formatUsageIcon(icon: string, value: string): string {
	return `${icon} ${value}`;
}

const LEFT_STATUS_EXCLUSIONS = new Set([
	"permission-mode",
	"mcp",
	"todo",
	"lsp",
]);

export function leftExtensionStatuses(
	statuses: ReadonlyMap<string, string>,
): string[] {
	const visible: string[] = [];
	for (const [key, status] of statuses) {
		if (status && !LEFT_STATUS_EXCLUSIONS.has(key)) visible.push(status);
	}
	return visible;
}

