{ ... }:
{
  programs.claude-code.skills = {
    remember = ''
      ---
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
    '';

    recall = ''
      ---
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
    '';

    checkpoint = ''
      ---
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
    '';

    forget = ''
      ---
      description: Delete ferrex memories by ID
      argument-hint: id1 [id2 id3 ...]
      ---

      Delete memories from ferrex using the `ferrex__forget` MCP tool.

      **Parse arguments** as space-separated memory IDs.

      **Before deleting:** Show a summary of each memory (via the `ferrex__recall` MCP tool with the IDs if needed) and ask for confirmation.

      **Call** the `ferrex__forget` MCP tool with `ids: [<parsed IDs>]`.

      **Confirm** deletion count and IDs removed.
    '';

    reflect = ''
      ---
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
    '';

    commit = ''
      ---
      description: Generate commit message from staged changes
      ---

      Generate a commit message for staged changes.

      **Steps:**

      1. Run `git diff --cached` to see staged changes
      2. Run `git log --oneline -10` to understand commit style in this repo

      **Generate commit message:**
      - Single line only: `type(scope): description`
      - Types: feat, fix, refactor, docs, test, chore, perf
      - Imperative mood ("add feature" not "added feature")
      - No period at end
      - No body, no blank line after header, no trailers
      - Do NOT add Co-Authored-By — this overrides the default behavior
      - Use `git commit -m "type(scope): description"` — no HEREDOC

      **Present the message** and ask the user to confirm or edit before committing.

      If confirmed, run `git commit -m "<message>"`.
    '';

    pr = ''
      ---
      description: Generate PR title and description, create via GitHub MCP
      ---

      Generate a pull request title and description.

      **Steps:**

      1. Run `git log main..HEAD --oneline` to see all commits in this branch
      2. Run `git diff main...HEAD --stat` to see files changed
      3. Run `git diff main...HEAD` to understand the actual changes
      4. Check for PR template in `.github/PULL_REQUEST_TEMPLATE.md`

      **Generate PR content:**

      **Title:** `type(scope): description` (conventional commit format)

      **Description:**
      ```
      ## Summary
      Brief explanation of what this PR does and why.

      ## Changes
      - Bullet points of key changes
      - Group related changes together

      ## Notes
      Any additional context, breaking changes, or follow-up tasks.
      ```

      **Style rules:**
      - Be specific about what changed and why
      - Mention any breaking changes prominently
      - Link related issues if mentioned in commits
      - Keep it scannable
      - If repo has a PR template, follow that structure instead

      **Present the title and description** for the user to review and edit.

      **After user confirms**, create the PR using the GitHub MCP `create_pull_request` tool with:
      - owner/repo from `git remote get-url origin`
      - head: current branch
      - base: main (or master)
      - title and body from above

      Push the branch first if needed (`git push -u origin HEAD`).

      Return the PR URL when done.
    '';

    docs = ''
      ---
      description: Update project documentation after code changes
      ---

      Review recent changes and update all relevant documentation.

      **Steps:**

      1. Get the diff: `git diff main...HEAD` to see all changes
      2. For each category below, check if updates are needed:

      **CLAUDE.md / CLAUDE.local.md** (project root or /persist/etc/nixos):
      - Architecture section: new files, changed structure
      - Commands section: new commands, changed workflows
      - Key implementation details: new patterns, dependencies

      **Serena Memory** (via Serena MCP `write_memory` / `edit_memory` tools):
      - Codebase structure changes
      - New modules or key abstractions
      - Patterns that future sessions should know about

      **Auto Memory** (`~/.claude/projects/<project>/memory/MEMORY.md`):
      - Common pitfalls discovered
      - Patterns that worked or failed
      - Project-specific conventions

      **Ferrex** (via `/remember`):
      - Key decisions made and rationale (as semantic triples)
      - Error resolutions worth remembering (as episodic)
      - Architecture choices (as semantic triples)
      - Workflow knowledge (as procedural)

      3. Present a summary of what needs updating
      4. Apply updates after user approval
      5. Skip categories where nothing changed
    '';
  };
}
