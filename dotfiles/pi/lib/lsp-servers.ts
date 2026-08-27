import { accessSync, constants, existsSync, statSync } from "node:fs";
import { dirname, extname, join, parse, resolve } from "node:path";

export type LspServerId = "gopls" | "tsgo";

export interface LspServerConfig {
	args: string[];
	command: string;
	id: LspServerId;
	languageId: string;
	rootMarkers: string[];
}

const TYPESCRIPT_EXTENSIONS = new Set([".ts", ".tsx", ".mts", ".cts"]);
const JAVASCRIPT_EXTENSIONS = new Set([".js", ".jsx", ".mjs", ".cjs"]);

export function serverForFile(path: string): LspServerConfig | undefined {
	const extension = extname(path).toLowerCase();
	if (extension === ".go") {
		return {
			id: "gopls",
			command: "gopls",
			args: ["serve"],
			languageId: "go",
			rootMarkers: ["go.work", "go.mod", ".git"],
		};
	}
	if (TYPESCRIPT_EXTENSIONS.has(extension) || JAVASCRIPT_EXTENSIONS.has(extension)) {
		return {
			id: "tsgo",
			command: "tsgo",
			args: ["--lsp", "--stdio"],
			languageId: TYPESCRIPT_EXTENSIONS.has(extension) ? "typescript" : "javascript",
			rootMarkers: ["tsconfig.json", "jsconfig.json", "package.json", ".git"],
		};
	}
	return undefined;
}

export function findWorkspaceRoot(file: string, markers: string[], fallback: string): string {
	const start = dirname(resolve(file));
	const filesystemRoot = parse(start).root;
	for (const marker of markers) {
		let directory = start;
		while (true) {
			if (existsSync(join(directory, marker))) return directory;
			if (directory === filesystemRoot) break;
			directory = dirname(directory);
		}
	}
	return resolve(fallback);
}

function executable(path: string): boolean {
	try {
		accessSync(path, constants.X_OK);
		return statSync(path).isFile();
	} catch {
		return false;
	}
}

export function resolveLspCommand(command: string, env: NodeJS.ProcessEnv = process.env): string | undefined {
	if (command.includes("/")) return executable(command) ? command : undefined;
	for (const directory of (env.PATH ?? "").split(":")) {
		if (!directory) continue;
		const candidate = join(directory, command);
		if (executable(candidate)) return candidate;
	}
	if (command === "gopls" && env.HOME) {
		const candidate = join(env.HOME, "go", "bin", "gopls");
		if (executable(candidate)) return candidate;
	}
	if (command === "tsgo") {
		const candidate = join(dirname(process.execPath), "tsgo");
		if (executable(candidate)) return candidate;
	}
	return undefined;
}
