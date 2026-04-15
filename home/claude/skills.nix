{ inputs, ... }:

{
  # Custom slash commands (stored in ~/.claude/skills/<name>/SKILL.md)
  home.file.".claude/skills/humanizer" = {
    source = inputs.humanizer;
    recursive = true;
  };

  programs.claude-code.skills = {
    remember = ''
      ---
      description: Store in ferrex memory (no args = session summary, with args = store that info)
      argument-hint: Optional info to store
      ---

      Store information in ferrex memory using `mcp__ferrex__store`.

      **Auto-set namespace** from project directory name.

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
      - `namespace`: project directory name
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

      Search ferrex memory using `mcp__ferrex__recall`.

      **Parse filters from arguments.** Remaining text becomes the semantic query:
      - `type:<type>` — filter by memory type (semantic, episodic, procedural)
      - `entity:<name>` — filter by linked entity
      - `date:<range>` — time range: `7d`, `30d`, or `<ISO-8601>..<ISO-8601>`

      **Auto-set namespace** from the current project directory name (basename of git root or pwd).

      **Build recall parameters:**
      - `query`: the semantic search text (or "recent context" if no query)
      - `namespace`: auto-detected project name
      - `types`: from type filter, if provided
      - `entities`: from entity filter, if provided
      - `time_range`: `{start, end}` in ISO-8601, from date filter
      - `limit`: 10 (default)
      - `validate_ids`: list of returned memory IDs (keeps access timestamps fresh)

      **Execute** `mcp__ferrex__recall` with built parameters.

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

      2. **Store in ferrex.** Call `mcp__ferrex__store` with:
         - `content`: full structured summary
         - `memory_type`: "episodic"
         - `namespace`: project directory name
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

      Delete memories from ferrex using `mcp__ferrex__forget`.

      **Parse arguments** as space-separated memory IDs.

      **Before deleting:** Show a summary of each memory (via `mcp__ferrex__recall` with the IDs if needed) and ask for confirmation.

      **Call** `mcp__ferrex__forget` with `ids: [<parsed IDs>]`.

      **Confirm** deletion count and IDs removed.
    '';

    reflect = ''
      ---
      description: Audit ferrex memory health
      argument-hint: [namespace:name|all]
      ---

      Run a memory health audit using `mcp__ferrex__reflect`.

      **Auto-set namespace** from project directory name, unless `namespace:all` or `namespace:<name>` specified.

      **Call** `mcp__ferrex__reflect` with:
      - `namespace`: detected or specified
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
  };
}
