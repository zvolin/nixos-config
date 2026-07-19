{ ... }:
{
  programs.claude-code.skills = {
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
      - Do NOT add Co-Authored-By trailers
      - Use `git commit -m "type(scope): description"` — no HEREDOC

      **Present the message** and ask the user to confirm or edit before committing.

      If confirmed, run `git commit -m "<message>"`.
    '';

    pr = ''
      ---
      description: Generate PR title and description, create via gh
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

      **After user confirms**, push the branch if needed (`git push -u origin HEAD`), then create the PR with `gh`:

      ```
      gh pr create --base main --head "$(git branch --show-current)" --title "<title>" --body "<body>"
      ```

      Use `--base master` if the repo's default branch is master. Return the PR URL that `gh pr create` prints.
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

      **Auto Memory** (`~/.claude/projects/<project>/memory/MEMORY.md`):
      - Common pitfalls discovered
      - Patterns that worked or failed
      - Project-specific conventions
      - Key decisions and their rationale

      3. Present a summary of what needs updating
      4. Apply updates after user approval
      5. Skip categories where nothing changed
    '';
  };
}
