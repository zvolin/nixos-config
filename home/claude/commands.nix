{ ... }:

{
  # Custom slash commands (stored in ~/.claude/commands/)
  programs.claude-code.settings.commands = {
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
  };
}
