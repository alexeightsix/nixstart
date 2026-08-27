/** Pure language inference for rendered code. No Pi or TUI imports. */

export interface CodeLanguageSegment {
	language: string;
	code: string;
}

const EXTENSIONS: Record<string, string> = {
	bash: "bash",
	c: "c",
	cc: "cpp",
	cpp: "cpp",
	css: "css",
	go: "go",
	h: "c",
	hpp: "cpp",
	html: "html",
	java: "java",
	js: "javascript",
	jsx: "javascript",
	json: "json",
	mjs: "javascript",
	php: "php",
	py: "python",
	rb: "ruby",
	rs: "rust",
	scss: "scss",
	sh: "bash",
	sql: "sql",
	ts: "typescript",
	tsx: "typescript",
	xml: "xml",
	yaml: "yaml",
	yml: "yaml",
	zsh: "bash",
};

export type DiffLineKind = "added" | "removed" | "context";

export interface SyntaxDiffStyler {
	/** Override local inference with the host renderer's language resolution. */
	language?: string;
	highlight(code: string, language: string): string[];
	styleDiff(kind: DiffLineKind, text: string): string;
}

const DELIMITERS: Record<string, string> = {
	BASH: "bash",
	CSS: "css",
	GO: "go",
	HTML: "html",
	JS: "javascript",
	JAVASCRIPT: "javascript",
	JSON: "json",
	PHP: "php",
	PY: "python",
	PYTHON: "python",
	RB: "ruby",
	RUBY: "ruby",
	RS: "rust",
	RUST: "rust",
	SH: "bash",
	SQL: "sql",
	TS: "typescript",
	TYPESCRIPT: "typescript",
	XML: "xml",
	YAML: "yaml",
	YML: "yaml",
};

export function languageFromPath(filePath: string): string | undefined {
	const clean = filePath.replace(/^['"]|['"]$/g, "").split(/[?#]/, 1)[0];
	const name = clean.split("/").at(-1)?.toLowerCase() ?? "";
	if (name === "dockerfile") return "dockerfile";
	const extension = name.includes(".") ? name.split(".").at(-1) : undefined;
	return extension ? EXTENSIONS[extension] : undefined;
}

export function filePathFromToolArgs(
	args: { path?: unknown; file_path?: unknown } | undefined,
): string | undefined {
	if (typeof args?.path === "string") return args.path;
	return typeof args?.file_path === "string" ? args.file_path : undefined;
}

/** Render a display-oriented edit diff without applying one diff colour to the source tokens. */
export function renderDiffWithSyntax(
	diffText: string,
	filePath: string,
	styler: SyntaxDiffStyler,
): string {
	const language = styler.language ?? languageFromPath(filePath);

	return diffText
		.split("\n")
		.map((line) => {
			const match = line.match(/^([+\- ])(\s*\d*)\s(.*)$/);
			if (!match) return styler.styleDiff("context", line);

			const prefix = match[1];
			const kind: DiffLineKind = prefix === "+" ? "added" : prefix === "-" ? "removed" : "context";
			if (!language) return styler.styleDiff(kind, line);

			const gutter = `${prefix}${match[2]} `;
			const source = match[3].replace(/\t/g, "   ");
			if (!match[2].trim() && source === "...") return styler.styleDiff("context", gutter + source);
			const highlighted = styler.highlight(source, language)[0] ?? source;
			return styler.styleDiff(kind, gutter) + highlighted;
		})
		.join("\n");
}

function heredocLanguage(opener: string, delimiter: string): string {
	const beforeHeredoc = opener.slice(0, opener.indexOf("<<"));

	if (/\b(?:python|python\d+(?:\.\d+)*)\b/.test(beforeHeredoc)) return "python";
	if (/\b(?:tsx|ts-node|deno)\b/.test(beforeHeredoc)) return "typescript";
	if (/\b(?:node|nodejs|bun)\b/.test(beforeHeredoc)) return "javascript";
	if (/\bruby\b/.test(beforeHeredoc)) return "ruby";
	if (/\bphp\b/.test(beforeHeredoc)) return "php";
	if (/\b(?:bash|zsh|sh)\b/.test(beforeHeredoc)) return "bash";
	if (/\b(?:psql|sqlite3?|mysql)\b/.test(beforeHeredoc)) return "sql";

	const targets = [...beforeHeredoc.matchAll(/(?:^|\s)(?:>|>>)\s*([^\s]+)/g)];
	const target = targets.at(-1)?.[1];
	const fromPath = target ? languageFromPath(target) : undefined;
	if (fromPath) return fromPath;

	return DELIMITERS[delimiter.toUpperCase()] ?? "bash";
}

/**
 * Split a shell command into Bash and embedded heredoc-language regions.
 * Unknown heredocs deliberately stay Bash rather than using auto-detection.
 */
export function splitShellLanguages(command: string): CodeLanguageSegment[] {
	const lines = command.split("\n");
	const segments: CodeLanguageSegment[] = [];
	let shellStart = 0;
	let index = 0;

	while (index < lines.length) {
		const opener = lines[index];
		const match = opener.match(/<<(-)?\s*(?:'([^']+)'|"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))/);
		if (!match) {
			index += 1;
			continue;
		}

		const delimiter = match[2] ?? match[3] ?? match[4];
		const stripTabs = match[1] === "-";
		let closing = index + 1;
		while (closing < lines.length) {
			const candidate = stripTabs ? lines[closing].replace(/^\t+/, "") : lines[closing];
			if (candidate === delimiter) break;
			closing += 1;
		}
		if (closing >= lines.length) {
			index += 1;
			continue;
		}

		segments.push({ language: "bash", code: lines.slice(shellStart, index + 1).join("\n") });
		if (closing > index + 1) {
			segments.push({
				language: heredocLanguage(opener, delimiter),
				code: lines.slice(index + 1, closing).join("\n"),
			});
		}
		shellStart = closing;
		index = closing + 1;
	}

	if (shellStart < lines.length) {
		segments.push({ language: "bash", code: lines.slice(shellStart).join("\n") });
	}
	return segments.length > 0 ? segments : [{ language: "bash", code: command }];
}

/** Conservative language inference for unlabelled Markdown fences. */
export function inferCodeLanguage(code: string): string | undefined {
	const text = code.trim();
	if (!text) return undefined;

	if ((text.startsWith("{") || text.startsWith("[")) && (() => {
		try {
			JSON.parse(text);
			return true;
		} catch {
			return false;
		}
	})()) return "json";

	if (/^#!.*\bpython\d*\b/m.test(text) || /^(?:from\s+[\w.]+\s+import\s+|import\s+[\w.]+|def\s+\w+\s*\(|class\s+\w+[:(])/m.test(text)) return "python";
	if (/^package\s+\w+/m.test(text) && /^(?:func|type|import|var|const)\b/m.test(text)) return "go";
	if (/^(?:use\s+[\w:]+|fn\s+\w+\s*\(|impl\s+\w+|struct\s+\w+)/m.test(text)) return "rust";
	if (/\b(?:interface\s+\w+|type\s+\w+\s*=|import\s+type\b|as\s+const\b)\b/.test(text)) return "typescript";
	if (/^(?:import|export)\s+.+\s+from\s+['"]|\b(?:const|let|var|function)\s+\w+|=>|console\.\w+\(/m.test(text)) return "javascript";
	if (/^(?:SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER|WITH)\b/im.test(text) && /\b(?:FROM|INTO|TABLE|SET|AS)\b/i.test(text)) return "sql";
	if (/^<!doctype\s+html|^<html\b|^<[A-Za-z][^>]*>[\s\S]*<\//i.test(text)) return "html";
	if (/^(?:[.#]?[A-Za-z][\w .#:[\]="'-]*|@media[^\{]*)\s*\{[\s\S]*:[^;{}]+;/m.test(text)) return "css";
	if (/^#!.*\b(?:ba|z|k)?sh\b/m.test(text) || /^(?:\$\s+)?(?:set\s+-[a-z]*e|cd|mkdir|mv|cp|rm|git|rg|find|curl|npm|pnpm|yarn|docker|kubectl)\b/m.test(text) || /\s(?:&&|\|\|)\s/.test(text)) return "bash";

	const yamlKeys = text.match(/^[A-Za-z_][\w.-]*:\s*(?:[^\[{].*)?$/gm) ?? [];
	if (/^---\s*$/m.test(text) || yamlKeys.length >= 2) return "yaml";
	return undefined;
}

/** Add render-only language labels to unlabelled fenced Markdown blocks. */
export function annotateUnlabelledFences(markdown: string): string {
	return markdown.replace(
		/(^|\n)([ \t]*)(`{3,}|~{3,})[ \t]*\n([\s\S]*?)\n\2\3(?=\n|$)/g,
		(full, prefix: string, indent: string, fence: string, code: string) => {
			const language = inferCodeLanguage(code);
			return language ? `${prefix}${indent}${fence}${language}\n${code}\n${indent}${fence}` : full;
		},
	);
}
