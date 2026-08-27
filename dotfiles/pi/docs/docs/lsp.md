---
title: LSP tools
---

# LSP tools

Pi exposes one read-only `lsp` tool for semantic code navigation. The tool starts the matching language server lazily for each workspace and reuses it for the session.

## Supported servers

| Files | Server | Command |
| --- | --- | --- |
| Go (`.go`) | `gopls` | `gopls serve` |
| TypeScript and JavaScript (`.ts`, `.tsx`, `.mts`, `.cts`, `.js`, `.jsx`, `.mjs`, `.cjs`) | TypeScript native preview (the Go implementation, `tsgo`) | `tsgo --lsp --stdio` |

The extension searches `PATH`; for Go installations it also checks `~/go/bin/gopls`, and for native TypeScript it checks beside the Node executable running Pi. A missing server produces an actionable tool error without preventing Pi from starting.

The far-right edge of the status line shows only `LSP ✓` when this extension loads. It deliberately omits individual server names and request state; actionable server failures remain in the `lsp` tool result. The LSP status is excluded from the general extension-status area so it never appears twice.

Workspace roots are selected by walking upward from the requested file in marker-priority order. Go prefers an enclosing `go.work`, then `go.mod`, then `.git`; TypeScript prefers `tsconfig.json`, then `jsconfig.json`, `package.json` and `.git`. If none is found, the server uses Pi's working directory.

## Actions

The `lsp` tool supports:

| Action | Required input | Result |
| --- | --- | --- |
| `hover` | file, line, symbol or column | Type and documentation at a position |
| `definition` | file, line, symbol or column | Definition locations |
| `references` | file, line, symbol or column | Reference locations, including the declaration |
| `symbols` | file | Symbols in the document |
| `diagnostics` | file | Current errors, warnings and hints |

Lines and columns supplied to the tool are one-based. Prefer `symbol` to identify the exact substring on that line; append `#N` to select its Nth occurrence. An explicit column remains available when the source spelling is not suitable. Results are compact paths and one-based ranges so they can be passed directly to the normal file tools. Files are opened or refreshed from disk before every request. A request honors cancellation and times out rather than leaving the agent blocked indefinitely.

These actions only inspect code. Rename, code actions, formatting and other operations that can modify files are deliberately not exposed, so the tool remains valid in `read-only` permission mode.

## Lifecycle

Language servers are not started during Pi startup. The first query for a language and workspace performs the LSP initialize handshake; later queries reuse that process. `/reload`, session replacement and Pi shutdown terminate all server processes owned by the old session.
