---
name: reflect
description: Audit ferrex memory health
argument-hint: [namespace:name|all]
---

Run a memory health audit using the `ferrex__reflect` MCP tool.

**Auto-set namespace** from the git repository name (basename of the repo root, not the worktree). If not in a git repo, use the basename of the working directory. Override with `namespace:all` or `namespace:<name>` if specified.

**Call** the `ferrex__reflect` MCP tool with:
- `namespace`: as determined above
- `include_contradictions`: true
- `include_stale`: true
- `limit`: 20

**Display results:**

For stale memories:
- Content summary, age, staleness score
- Suggest: `/forget <id>` to remove, or `/remember` updated version to supersede

For contradictions:
- Show both conflicting triples side by side
- Suggest: `/remember` the correct fact with `supersedes` pointing to the old memory ID

**After showing results:** Offer to batch-forget stale entries or help resolve contradictions.
