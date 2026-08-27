---
title: MCP
---

# MCP

MCP servers reach Pi through `pi-mcp-adapter`, which exposes a single proxy tool (~200 tokens) instead of loading every server's tool definitions into the context window. Servers start on first use.

`mcp.json` is the tracked global override linked to `~/.pi/agent/mcp.json`, so Pi uses the same server inventory on every project.

| Server | Transport | Auth |
| --- | --- | --- |
| `figma` | `https://mcp.figma.com/mcp` | OAuth |
| `linear` | `https://mcp.linear.app/mcp` | OAuth |
| `fathom` | `https://api.fathom.ai/mcp` | OAuth |
| `trello` | `https://mcp.trello.com/v1` | OAuth |
| `chrome-devtools` | `npx chrome-devtools-mcp@latest` | none |

All are `lifecycle: lazy` — nothing is spawned or connected until a tool from that server is actually called.

## Write protection on Linear

Linear's mutating tools require approval:

```json
"approveTools": ["create_*", "update_*", "delete_*", "save_*", "archive_*", "merge_*"]
```

Reads go through unattended; anything that changes an issue, project, or document asks first. This is independent of the [permission mode](./modes.md), which governs local tools rather than MCP.

## Managing servers

```
/mcp            panel: servers, status, tools
/mcp setup      import from other hosts, or scaffold a new server
```

`hostConfigDiscovery` is `off`, so Pi uses only `mcp.json` and does not silently adopt another host application's server list. Add a server by editing `mcp.json` in this repository — it is the tracked copy.
