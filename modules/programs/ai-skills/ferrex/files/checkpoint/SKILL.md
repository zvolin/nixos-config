---
name: checkpoint
description: Save session context to ferrex before context clear
---

Snapshot session state to ferrex so the next context can resume without re-research.

**Steps:**

1. **Summarize session state.** Collect:
   - Goal: one-line session/task goal
   - Approach taken and key decisions
   - Progress (checkboxes: `[x]` done, `[ ]` remaining)
   - Gotchas discovered (file:line refs)
   - Next steps (exactly what to do first when resuming)

2. **Store in ferrex.** Call the `ferrex__store` MCP tool with:
   - `content`: full structured summary
   - `memory_type`: "episodic"
   - `namespace`: git repository name (basename of the repo root, not the worktree); basename of the working directory if not in a git repo
   - `entities`: project name, "checkpoint", branch name, key topics
   - `context`: affected file paths, branch name

3. **Confirm.** Tell the user:
   - What was stored (summary)
   - Memory ID
   - Resume hint: `Recall checkpoint: "<goal>"`
