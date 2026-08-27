const SHELL_SEGMENT_RE = /[;&|()\n]+/;
const TOKEN_RE = /(?:[^\s"'\\]+|"(?:\\.|[^"])*"|'[^']*')+/g;
const GIT_OPTIONS_WITH_VALUES = new Set([
	"-C",
	"-c",
	"--config-env",
	"--exec-path",
	"--git-dir",
	"--namespace",
	"--super-prefix",
	"--work-tree",
]);

function unquote(token: string): string {
	if (
		(token.startsWith('"') && token.endsWith('"')) ||
		(token.startsWith("'") && token.endsWith("'"))
	) {
		return token.slice(1, -1);
	}
	return token;
}

function isAllowedGitPrefix(tokens: string[]): boolean {
	return tokens.every((token) => {
		const value = unquote(token);
		return (
			/^[A-Za-z_][A-Za-z0-9_]*=/.test(value) ||
			value === "command" ||
			value === "env" ||
			value === "sudo" ||
			value.startsWith("-")
		);
	});
}

export function directGitShipSubcommand(command: string): "commit" | "push" | undefined {
	for (const segment of command.split(SHELL_SEGMENT_RE)) {
		const tokens = segment.match(TOKEN_RE) ?? [];
		const gitIndex = tokens.findIndex((token) => /(?:^|\/)git$/.test(unquote(token)));
		if (gitIndex < 0 || !isAllowedGitPrefix(tokens.slice(0, gitIndex))) continue;

		for (let index = gitIndex + 1; index < tokens.length; index += 1) {
			const token = unquote(tokens[index] ?? "");
			if (!token.startsWith("-")) {
				return token === "commit" || token === "push" ? token : undefined;
			}
			if (GIT_OPTIONS_WITH_VALUES.has(token)) index += 1;
		}
	}
	return undefined;
}
