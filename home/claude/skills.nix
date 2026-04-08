{ ... }:

{
  # Custom slash commands (stored in ~/.claude/skills/<name>/SKILL.md)
  programs.claude-code.skills = {
    handoff = ''
      ---
      description: Generate a handoff document for continuing work in a fresh session
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
      description: Spawn a researcher agent to investigate a topic
      argument-hint: <topic or question>
      ---

      ## Task

      The user wants to research: $ARGUMENTS

      ## Instructions

      1. Spawn a researcher agent (subagent_type: "general-purpose") with the following prompt:

         "You are acting as a researcher agent. Follow the researcher agent instructions.
          Investigate the following topic: $ARGUMENTS

          Context:
          - Current directory: the project root
          - Git status: check with git status
          - Recent changes: check with git log --oneline -10

          Return your findings in the structured format specified in your agent instructions."

      2. The agent should run in the main worktree (no isolation needed — it is read-only).
      3. Present the agent's findings to the user.
      4. Ask if they want to dig deeper into any area or proceed to planning.
    '';

    design = ''
      ---
      description: Research a goal then produce an implementation plan
      argument-hint: <goal description>
      ---

      ## Task

      The user wants to plan: $ARGUMENTS

      ## Instructions

      This is a two-phase workflow:

      ### Phase 1: Research

      Spawn a researcher agent to gather context about the goal:
      - What existing code is relevant?
      - What constraints exist?
      - What patterns does the codebase use?

      Present the research findings to the user. Ask if they want to adjust the goal
      or add constraints before planning.

      ### Phase 2: Planning

      After the user approves the research, spawn a planner agent with:
      - The original goal: $ARGUMENTS
      - The research findings from phase 1
      - Any additional constraints the user specified

      The planner should produce a plan with tasks grouped into waves (parallel batches).
      Save the plan to `docs/plans/` in the project.

      Present the plan to the user for approval. Do NOT proceed to implementation.
    '';

    implement = ''
      ---
      description: Execute an implementation plan using parallel agents in worktrees
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

      1. **Announce** which tasks are in this wave
      2. **Spawn implementer agents in parallel**, one per task, each with:
         - `isolation: "worktree"` for workspace isolation
         - The specific task description from the plan
         - Context about the project and any outputs from previous waves
         - Branch naming: `agent/<plan-name>/<task-number>`
      3. **Wait** for all agents in the wave to complete
      4. **Present results** — for each agent: what was done, branch name, test results, any issues
      5. **Ask for approval** before moving to the next wave
         - If any agent failed, ask the user how to proceed (skip, retry, fix manually)

      ### Step 3: Summarize

      After all waves complete, present:
      - List of all branches created
      - Suggested merge order (respecting dependencies)
      - Any unresolved issues

      Do NOT automatically merge branches. The user decides what to merge.
    '';

    review = ''
      ---
      description: Spawn a reviewer agent to review code changes
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
         - Instructions to follow the reviewer agent format

      3. The agent should run in the main worktree (no isolation needed — it is read-only).
      4. Present the review findings to the user.
      5. If verdict is REQUEST_CHANGES, ask if they want help fixing the issues.
    '';
  };
}
