{ ... }:

{
  # Custom slash commands (stored in ~/.claude/skills/<name>/SKILL.md)
  programs.claude-code.skills = {
    handoff = ''
      ---
      description: Use when ending a session and need to preserve context for the next one
      ---

      ## Context

      - Current git status: !`git status`
      - Recent commits: !`git log --oneline -10`
      - Current diff: !`git diff`

      ## Task

      Write a HANDOFF.md in the project root summarizing:

      1. **Goal** — what we're trying to accomplish (1-2 sentences)
      2. **What's done** — completed work, with file paths
      3. **What failed** — approaches that didn't work and why (skip if none)
      4. **What's next** — concrete next steps, ordered by priority
      5. **Key decisions** — non-obvious choices made and their rationale
      6. **Commands** — build/test/run commands relevant to this work

      Keep it concise — this will be pasted as the opening message of a fresh session.
      Do NOT include information that can be derived from reading the code or git history.
      Focus on context that would be lost between sessions: intent, reasoning, gotchas.
    '';

    research = ''
      ---
      description: Use when you need to investigate a topic, gather context, or understand something before acting
      argument-hint: <topic or question>
      ---

      ## Task

      The user wants to research: $ARGUMENTS

      ## Instructions

      1. Spawn a researcher agent (subagent_type: "general-purpose") with the following prompt:

         "You are a research specialist. Investigate the following topic thoroughly: $ARGUMENTS

          ## Rules
          - NEVER write, edit, or create files
          - NEVER run commands that modify state
          - Be thorough — check multiple sources, cross-reference findings
          - Use ultrathink when synthesizing findings

          ## Context
          - Git status: !`git status --short`
          - Recent changes: !`git log --oneline -10`
          - Current branch: !`git branch --show-current`

          ## Output Format
          Structure your response as:
          ### Findings — key discoveries, organized by subtopic
          ### Relevant Files — paths and brief descriptions
          ### Constraints & Gotchas — non-obvious limitations
          ### Open Questions — things to investigate further"

      2. The agent should run in the main worktree (no isolation needed — it is read-only).
      3. Present the agent's findings to the user.
      4. Ask if they want to dig deeper into any area or proceed to planning.
    '';

    design = ''
      ---
      description: Use when you have a goal that needs research and an implementation plan before coding
      argument-hint: <goal description>
      ---

      ## Context

      - Git status: !`git status --short`
      - Recent commits: !`git log --oneline -5`
      - Current branch: !`git branch --show-current`

      ## Task

      The user wants to plan: $ARGUMENTS

      ## Instructions

      This is a two-phase workflow:

      ### Phase 1: Research

      Spawn a researcher agent to gather context about the goal:
      - What existing code is relevant?
      - What constraints exist?
      - What patterns does the codebase use?

      Use the superpowers:brainstorming skill to explore the solution space before narrowing down.

      Present the research findings to the user. Ask if they want to adjust the goal
      or add constraints before planning.

      ### Phase 2: Planning

      After the user approves the research, spawn a planner agent with:
      - The original goal: $ARGUMENTS
      - The research findings from phase 1
      - Any additional constraints the user specified

      Use the superpowers:writing-plans skill for plan structure.
      Ensure each task in the plan is a 2-5 minute chunk, clear enough for an implementer agent with no prior context.

      The planner should produce a plan with tasks grouped into waves (parallel batches).
      Save the plan to `docs/plans/` in the project.

      Present the plan to the user for approval. Do NOT proceed to implementation.
    '';

    implement = ''
      ---
      description: Use when you have a saved plan document ready for execution
      argument-hint: <path to plan document>
      ---

      ## Task

      The user wants to implement the plan at: $ARGUMENTS

      ## Instructions

      ### Step 1: Read and parse the plan

      Read the plan document at the specified path. Identify:
      - All tasks and their descriptions
      - Dependencies between tasks (which tasks block others)
      - Grouping into waves (independent tasks in the same wave)

      Present a summary: "Found N tasks in M waves" with the wave breakdown.
      Ask the user to confirm before proceeding.

      ### Step 2: Execute waves sequentially

      For each wave, starting with wave 1:

      Use the superpowers:dispatching-parallel-agents skill for agent orchestration.

      1. **Announce** which tasks are in this wave
      2. **Spawn implementer agents in parallel**, one per task, each with:
         - `isolation: "worktree"` for workspace isolation
         - The specific task description from the plan
         - Context about the project and any outputs from previous waves
         - Branch naming: `agent/<plan-name>/<task-number>`
         - Use the superpowers:using-git-worktrees skill for worktree management.
      3. **Wait** for all agents in the wave to complete
      4. **Present results** — for each agent: what was done, branch name, test results, any issues
      5. **Clean up worktrees** — after presenting results and before asking for approval:
         - For each agent that returned DONE: remove its worktree with `git worktree remove <path>`
         - Do NOT remove worktrees for agents that returned DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
           (the user may want to inspect or retry)
         - List any worktrees that were kept and why
      6. **Ask for approval** before moving to the next wave
         - Handle agent status codes:
           - **DONE** — mark task complete, delete the task branch (`git branch -d <branch>`), proceed
           - **DONE_WITH_CONCERNS** — show concerns to user, ask whether to proceed or address them
           - **NEEDS_CONTEXT** — present what the agent needs, provide it or skip
           - **BLOCKED** — show blocker, ask user how to proceed (skip, fix manually, retry with more context)

      ### Step 3: Summarize

      Use the superpowers:finishing-a-development-branch skill for merge preparation.

      After all waves complete, present:
      - List of all branches created
      - Suggested merge order (respecting dependencies)
      - Any unresolved issues

      Do NOT automatically merge branches. The user decides what to merge.
      NEVER merge into main/master — accumulate work in a dedicated feature branch.

      After presenting the summary, ask the user if they want to run `/review` on the feature branch before merging.
    '';

    review = ''
      ---
      description: Use when code changes need review — after implementation, before merge, or on request
      argument-hint: [branch, commit range, or file paths]
      ---

      ## Task

      The user wants a code review of: $ARGUMENTS

      ## Instructions

      1. Determine what to review:
         - If $ARGUMENTS is a branch name: review the diff against main
         - If $ARGUMENTS is a commit range: review those commits
         - If $ARGUMENTS is file paths: review those files
         - If $ARGUMENTS is empty: review uncommitted changes (staged + unstaged)

      2. Spawn a reviewer agent (subagent_type: "general-purpose") with:
         - The relevant diff or file contents
         - Any plan document in `docs/plans/` that seems related to the changes
         - Use the superpowers:requesting-code-review skill for review methodology
         - Include these instructions in the prompt:

           "You are a code review specialist. Review the provided changes.

            ## Rules
            - NEVER edit, write, or create files
            - Review against the plan/spec if provided
            - Be specific — reference exact files and line numbers
            - Use ultrathink when evaluating non-trivial logic

            ## Review Process
            Pass 1 — Spec Compliance: Does it do what was asked? All requirements met? No scope creep?
            Pass 2 — Code Quality: Correctness, security, style, simplicity.

            ## Codex Second Opinion
            For blocker/warning findings, get a second opinion via /codex skill in read-only mode.

            ## Output Format
            ### Summary — one paragraph assessment
            ### Findings — for each: File, Severity (blocker|warning|suggestion), Description, Suggestion
            ### Verdict — APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION
            ### Learnings — patterns for future work (category: insight)"

      3. The agent should run in the main worktree (no isolation needed — it is read-only).
      4. Present the review findings to the user.
      5. If verdict is REQUEST_CHANGES, ask if they want help fixing the issues.
      6. If the review produced any Learnings entries, offer to save them to the project's
         memory system so they inform future sessions. Only do this with user approval.
      7. **Post-merge cleanup** — if the user merges the reviewed branch:
         - Delete the merged branch locally: `git branch -d <branch>`
         - If the branch was a feature branch aggregating agent work, also clean up:
           - Any remaining agent worktrees: `git worktree remove <path>` for each
           - Any remaining agent branches: `git branch -d <branch>` for each
         - Confirm cleanup: "Cleaned up branch `<name>` and N agent worktrees/branches."
         - If any branch cannot be deleted (unmerged changes), warn the user instead of force-deleting
    '';

    learn = ''
      ---
      description: Use after completing a task or review to capture learnings and improve future work
      argument-hint: [topic or "from-review"]
      ---

      ## Task

      Capture and persist learnings from recent work.

      ## Instructions

      1. **Gather context:**
         - If $ARGUMENTS is "from-review": read the most recent review output in conversation
         - If $ARGUMENTS is a topic: examine recent git history and conversation for insights on that topic
         - If $ARGUMENTS is empty: ask what area to capture learnings from

      2. **Identify learnings** — look for:
         - Patterns that worked well (repeat these)
         - Mistakes or surprises (avoid these)
         - Non-obvious constraints discovered
         - Architecture decisions and their rationale
         - Security or correctness gotchas

      3. **Classify each learning:**
         - `architecture` — structural decisions, module boundaries
         - `security` — vulnerabilities, safe patterns
         - `testing` — test strategies, coverage gaps
         - `style` — conventions, readability patterns
         - `performance` — optimization insights
         - `process` — workflow improvements, tooling insights

      4. **Present learnings** to user in this format:
         ```
         ### Proposed Learnings
         - <category>: <insight>
         - <category>: <insight>
         ```

      5. **With user approval**, save each learning to the appropriate place:
         - Project-specific patterns → project memory file
         - General workflow insights → feedback memory file
         - Do NOT save things derivable from code or git history
    '';
  };
}
