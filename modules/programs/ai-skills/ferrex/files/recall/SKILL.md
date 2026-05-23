---
name: recall
description: Search ferrex memory
argument-hint: query [type:semantic|episodic|procedural] [entity:name] [date:7d|30d|start..end]
---

Search ferrex memory using the `ferrex__recall` MCP tool.

**Parse filters from arguments.** Remaining text becomes the semantic query:
- `type:<type>` — filter by memory type (semantic, episodic, procedural)
- `entity:<name>` — filter by linked entity
- `date:<range>` — time range: `7d`, `30d`, or `<ISO-8601>..<ISO-8601>`

**Auto-set namespace** from the git repository name (basename of the repo root, not the worktree). If not in a git repo, use the basename of the working directory.

**Build recall parameters:**
- `query`: the semantic search text (or "recent context" if no query)
- `namespace`: git repository name (basename of the repo root, not the worktree); basename of the working directory if not in a git repo
- `types`: from type filter, if provided
- `entities`: from entity filter, if provided
- `time_range`: `{start, end}` in ISO-8601, from date filter
- `limit`: 10 (default)
- `validate_ids`: list of returned memory IDs (keeps access timestamps fresh)

**Execute** the `ferrex__recall` MCP tool with built parameters.

**Display results.** For each result:
- Content (truncated if long)
- Type | staleness indicator | entities | age
- Memory ID (for use with /forget)

**No arguments:** Search recent context for current project namespace.

**After showing results:** Suggest related searches based on entities found.
