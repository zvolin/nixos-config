---
name: remember
description: Store in ferrex memory (no args = session summary, with args = store that info)
argument-hint: Optional info to store
---

Store information in ferrex memory using the `ferrex__store` MCP tool.

**Auto-set namespace** from the git repository name (basename of the repo root, not the worktree). If not in a git repo, use the basename of the working directory.

**If arguments provided**, detect memory type from content:

1. **Semantic triple** — if the content is a fact, decision, or relationship:
   - Extract `subject`, `predicate`, `object`
   - Example: "nix-darwin uses lze for plugin loading" -> subject: "nix-darwin", predicate: "uses", object: "lze for plugin loading"
   - Example: "We decided to use ferrex instead of qdrant" -> subject: "project", predicate: "decided", object: "use ferrex instead of qdrant"
   - Set `memory_type: "semantic"`

2. **Procedural** — if the content describes a workflow, process, or how-to:
   - Store as `content` with `memory_type: "procedural"`

3. **Episodic** — events, errors, observations, anything else:
   - Store as `content` with `memory_type: "episodic"`

**Always set:**
- `namespace`: git repository name (basename of the repo root, not the worktree); basename of the working directory if not in a git repo
- `entities`: at minimum the project name. Add relevant concept names (tools, modules, patterns mentioned).
- `context`: branch name, relevant file paths
- `confidence`: 1.0 unless the user expresses uncertainty

**If no arguments**, summarize the conversation and store as episodic with entities for the project, branch, and key topics discussed.

**After storing:** Confirm what was stored — type, entities, namespace, and memory ID.
