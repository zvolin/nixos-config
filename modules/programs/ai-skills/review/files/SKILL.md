---
name: review
description: Produce a read-only code review report from a diff. Runs parallel reviewers, folds their findings through adjudication and humanization, and saves the report under docs/superpowers/reviews/. Shadows the built-in /review command.
---

# Review

You are the review controller. Produce a single humanized review report and print it inline. Every phase is read-only — you never commit, never touch branches, never edit files outside the staging directory and the final report path.

**Announce at start:** "Using the review skill." Then run the phases below in order.

## Phase 0: Parse arguments and resolve refs

The invocation grammar, evaluated left-to-right, first match wins:

| Invocation | Meaning | Asks base? |
|------------|---------|------------|
| `/review` | current branch vs `main` | no |
| `/review onto <target>` | current branch vs `<target>` | no |
| `/review <ref> onto <target>` | `<ref>` vs `<target>` | no |
| `/review <int>` | GitHub PR number for the current repo | no |
| `/review <sha>` | commit vs current-branch-or-main | yes |
| `/review <branch>` | branch vs current-branch-or-main | yes |

**Ambiguity resolution:**

- Bare digits (matches `^[0-9]+$`) → PR mode.
- Otherwise use `git rev-parse --verify <arg>` and `git rev-parse --verify <arg>^{commit}`:
  - If `<arg>` matches `^[0-9a-f]{7,40}$` and resolves → treat as SHA.
  - Else if it resolves as a ref → treat as branch.
  - Else respond: "Could not resolve `<arg>` as a SHA, branch, or PR number." and stop.
- If current branch is `main` or HEAD is detached and `/review` was given no args (or `onto <target>` with no ref), respond: "No branch to review. Pass a commit, branch, or PR number." and stop.

**Base ambiguity.** In SHA and bare-branch modes (no `onto` clause), ask a single `AskUserQuestion`:

- Body: "Which base should this be reviewed against?"
- Options:
  1. `current branch (<name>@<short-sha>)` — only offered when the current branch is not `main` and is not detached.
  2. `main`
  3. `Other` — free-form ref. If the entered ref doesn't resolve, re-ask once, then stop.

**PR mode.** Derive `<owner>/<repo>` from `git remote get-url origin` (require an origin remote pointing at github.com — otherwise respond: "PR mode requires an `origin` remote on github.com." and stop). Call `pull_request_read` from the GitHub MCP with that owner/repo. If the call errors (nonexistent PR, permission denied, network), print the error and stop — do not attempt a worktree.

On success, record the PR head SHA, base branch, title, body, URL, and linked issues. Fetch the head locally so reviewers can browse files:

```
git fetch origin pull/<n>/head:refs/pr/<n>
```

Set `head = refs/pr/<n>`, `base = <pr-base-branch>`, `name = pr-<n>`.

**Fill in ref names for other modes:**

- No args: `base = main`, `head = <current-branch>`, `name = main-vs-<current-branch>`
- `onto <target>` alone: `base = <target>`, `head = <current-branch>`, `name = <target>-vs-<current-branch>`
- `<ref> onto <target>`: `base = <target>`, `head = <ref>`. If `<ref>` is a SHA use its 8-char short form for `name`; else use the branch name. `name = <target>-vs-<ref-or-short-sha>`
- `<sha>`: `base` from the ambiguity prompt, `head = <sha>`, `name = <base>-vs-<short-sha>` (8-char short)
- `<branch>`: `base` from the ambiguity prompt, `head = <branch>`, `name = <base>-vs-<branch>`

Compute `short_run_id` as a random 8-hex string (e.g., first 8 chars of a `date +%s%N | sha256sum` hash — any 8 hex chars are fine as long as they don't collide with an existing worktree).

## Phase 1: Create the worktree

Set `repo_root` from `git rev-parse --show-toplevel`. Set `worktree_path = <repo_root>/.git-worktree-review-<short_run_id>` and `staging_dir = <repo_root>/docs/superpowers/reviews/_<name>`.

Run: `git worktree add --detach <worktree_path> <head>` from the repo root. `<head>` is whatever Phase 0 resolved — a branch tip, a SHA, or a `refs/pr/<n>` ref for PR mode. `--detach` is required so a branch checked out at the repo root doesn't collide.

If the command fails, print the error and stop.

Track two flags for cleanup:

- `created_worktree = true`
- `pr_ref_created` — true only if Phase 0 fetched a `refs/pr/<n>` ref (PR mode)

## Phase 2: Prepare the staging directory

Create `<staging_dir>` (absolute path). Any existing contents are removed first (`rm -rf <staging_dir>`). This is the drop zone for subagent reports and lives in the repo root, not the worktree — every subagent prompt uses the absolute path so writes don't land in the worktree's own gitignored copy.

## Phase 2.5: Classify the diff

From the worktree, compute a diff summary. The commands below assume you have already `cd`'d into `<worktree_path>` — do that first.

**File-level stats:**

- `git diff --name-status <base>...<head>` → files changed / added / removed / renamed
- `git diff --numstat <base>...<head>` → lines added / removed per file (raw)

**Effective LOC:** raw lines minus every line in files matching any of these globs (matched with `git check-attr` or, more simply, plain shell glob against each file path):

- `*.lock`
- `Cargo.lock`, `flake.lock`, `pnpm-lock.yaml`, `package-lock.json`
- `*.min.*`
- `vendor/**`
- `**/*.snap`

**Path buckets.** Assign each changed file to exactly one bucket, first match wins:

1. **crucial** — any of `**/auth/**`, `**/crypto/**`, `**/security/**`, `**/migrations/**`, `**/*.sql`, `**/policy/**`, `**/rbac/**`, `**/keychain*`, `**/secret*`
2. **lockfile** — any of the effective-LOC skip globs above
3. **generated** — files with a `# generated` / `// generated` marker in the first 5 lines, or paths containing `generated/`, `.pb.go`, `.pb.rs`, `.pb.ts`
4. **test** — paths containing `test/`, `tests/`, `__tests__/`, or names ending in `_test.{ext}` / `.test.{ext}` / `.spec.{ext}`
5. **config** — top-level dotfiles, `**/*.toml`, `**/*.yaml`, `**/*.yml`, `**/*.ini`, `**/*.json` (unless already generated), `**/*.nix`
6. **docs** — `**/*.md`, `**/*.rst`, `**/*.txt`, `docs/**`
7. **app** — everything else

Log the bucket assignment as a short table so the user can see the reasoning.

**Complexity tier:**

- `mechanical` — no logic edits: pure renames (per `--name-status R`), formatting-only diffs (no non-whitespace changes in a hunk), comment-only edits, config bumps
- `minor-logical` — logic edits confined to non-crucial paths
- `crucial-logical` — any hit in the `crucial` bucket, regardless of size

**Reviewer count formula:**

| Tier             | ≤300 | 301–800 | >800 |
|------------------|------|---------|------|
| mechanical       | 1    | 1       | 2    |
| minor-logical    | 1    | 2       | 2    |
| crucial-logical  | 2    | 2       | 3    |

For effective LOC > 800: `reviewers = max(table_value, ceil(effective_LOC / 800))`.

Per-tier caps: mechanical 2, minor-logical 4, crucial-logical 5.

**Codex reviewer** is proposed when tier is `crucial-logical` OR effective LOC > 600 OR ≥4 crucial-bucket files.

**Gap-finder pass** is proposed under the same triggers.

Record the results as `plan_proposal`:

- `tier`, `raw_loc`, `effective_loc`, `bucket_counts`
- `reviewers` (int)
- `codex` (bool)
- `gap_finder` (bool)

## Phase 2.6: Confirm the plan

Use the `AskUserQuestion` tool. The question body carries the plan proposal (tier, effective LOC, reviewers, codex, gap-finder, bucket breakdown). Options:

1. **Accept as proposed** (recommended) — use the proposal verbatim
2. **Lighter** — 1 reviewer, no codex, no gap-finder. Only include this option when tier is not `crucial-logical`.
3. **Heavier** — reviewers + 1 (bounded by the per-tier cap), force codex on, force gap-finder on
4. **Other** — free-form; parse strings like "3 reviewers, no codex, gap-finder". If the string can't be parsed, re-ask with a cleaner form once, then stop.

Store the final choice as `plan` (same fields as `plan_proposal`).

**Unsatisfiable constraint.** If tier is `crucial-logical` and the resolved `plan.reviewers` is 1 (only reachable via Other), the ≥2-reviewers-per-crucial-slice rule in Phase 2.7 can't be met. Re-ask once with a note: "This diff touches crucial paths and needs at least 2 reviewers. Pick a value ≥2 or type `override` to proceed with 1 anyway." Accept `override` verbatim — the user knows.

## Phase 2.7: Assign slices to reviewers

If `effective_loc ≤ 800 × plan.reviewers`, every reviewer gets the whole diff. Skip the rest of this phase — set `slices = [{ reviewer: i, paths: <all> } for i in 1..plan.reviewers]`.

Otherwise partition:

1. Group changed files by top-level path segment (e.g. `src/auth/`, `modules/services/`, `docs/`).
2. Any group whose effective LOC > 800: subdivide by the next directory level.
3. Any group still > 800: split by file.
4. Never split mid-hunk. A file that is itself > 800 LOC counts as a single unit and gets multiple reviewers on it.

Now assign slices to reviewers under these constraints:

- Every slice containing a `crucial`-bucket file gets ≥2 reviewers.
- Every non-crucial slice gets ≥1 reviewer.
- Per-reviewer effective-LOC load stays ~800 (soft target — the crucial rule wins on ties).

Each reviewer also receives the full diff as *reference context*. Instruct them: "Deep-review your assigned slices only. Skim the rest and flag cross-slice smells in a separate section."

## Phase 2.8: Map rules to reviewers

For each changed file, look up its extension in this table and collect the union of rule names:

| Extension | Rule name |
|-----------|-----------|
| `.rs` | languages/rust |
| `.py` | languages/python |
| `.ts`, `.tsx`, `.js` | languages/typescript |
| `.go` | languages/go |
| `.java` | languages/java |
| `.kt` | languages/kotlin |
| `.swift` | languages/swift |
| `.css` | languages/css |
| `.html` | languages/html |

Extensions with no mapping (e.g. `.nix`) are skipped without error. Markdown and other prose files are excluded — only the prose reviewer touches them, via the humanizer rubric.

Add `base/core` and `base/git` unconditionally. The final list is `code_rules`.

Every code, idiomatic, and cleanup reviewer's prompt includes a line: `Load these rule files from ~/.claude/rules/: <comma-separated code_rules>`.

The prose reviewer does not get language rules — it uses the humanizer skill's rubric instead.

## Phase 3: Dispatch all reviewers in parallel

In a single message, issue N parallel `Agent` tool calls — one per reviewer below. Every prompt starts with:

- Worktree path with an instruction to `cd <worktree_path>` before any git command.
- `<base>` and `<head>` refs.
- The diff command: `git diff <base>...<head>`.
- The assigned slices as a path list, plus a note that the full diff is available as reference context.
- The rule-load line (see Phase 2.8) — code / idiomatic / cleanup reviewers only.
- The role-specific rubric (below).
- The output path in the staging directory.
- The finding format: `Critical / Important / Minor`, each with `file:line` + rationale, and a separate "Cross-slice smells" section.
- Closing line: "You are read-only. Do not modify any file except your assigned report path. Do not create branches, commits, or PRs."

Every output path below is joined against `<staging_dir>` (absolute), not the worktree.

**Standing agents (always dispatched):**

| Agent | Subagent type | Model | Output path |
|-------|---------------|-------|-------------|
| Code reviewer × `plan.reviewers` (indices 1..N) | `superpowers:code-reviewer` | opus | `<staging_dir>/code-review-<i>.md` |
| Idiomatic-pass reviewer | `general-purpose` | opus | `<staging_dir>/idiomatic.md` |
| Cleanup reviewer | `general-purpose` | opus | `<staging_dir>/cleanup.md` |
| Prose/comment reviewer | `general-purpose` | opus | `<staging_dir>/prose.md` |

**Conditional (per the plan):**

| Agent | Subagent type | Model | Output path |
|-------|---------------|-------|-------------|
| Codex reviewer (when `plan.codex` is true) | `general-purpose` | inherit | `<staging_dir>/codex.md` |

**Role rubrics:**

- **Code reviewer:** correctness, boundary conditions, error handling, security, tests, architecture fit. Uses `superpowers:code-reviewer` conventions.
- **Idiomatic-pass:** for every changed file, check the change against the surrounding file's idioms — naming, error handling, abstraction level, language patterns. Flag every deviation that lacks a load-bearing reason.
- **Cleanup:** dead code, over-engineering, AI artifacts, redundant validation, simplifications. Same rubric as the `cleanup` skill.
- **Prose/comment:** invoke the `humanizer` skill first to load its rubric. Then for every added or changed comment, docstring, and error message in the diff, flag any pattern hit — restating code, AI-obvious phrasing, sycophantic docstrings, promotional language.
- **Codex:** invoke the `skill-codex` skill to hand the diff to the codex CLI. Ask codex for a grounding pass — verify claims in code (log messages, error strings, boundary asserts) match reality, and surface edge cases the primary reviewers missed. Codex writes back into the staging file at the specified path.

## Phase 3.5: Handle parallel-phase failures

If a subagent errors or times out, keep the others' outputs. Write a stub inside `<staging_dir>` renamed with a `.failed.md` suffix (e.g. `<staging_dir>/codex.failed.md`) whose body is one line naming the failure (e.g. "codex CLI timed out after 120s"). Record `parallel_failure = true`. The pipeline continues — Phase R2's adjudicator sees the gap.

Every subagent output below uses an absolute path under `<staging_dir>`.

## Phase R1: Gap-finder (conditional)

Skip this phase when `plan.gap_finder` is false.

Use the `Agent` tool with `subagent_type: general-purpose`, `model: opus`. Prompt contents:

- Worktree path + `cd` instruction.
- `<base>` and `<head>` refs.
- Every file under `<staging_dir>/` as reference material (list the absolute paths; the subagent reads them).
- The full diff command.
- Task: find what the parallel reviewers missed — omitted edge cases, cross-cutting concerns, integration risks, absent tests. Report under the same `Critical / Important / Minor` taxonomy.
- Absolute output path: `<staging_dir>/gap-finder.md`.
- Read-only closing line.

## Phase R2: Adjudicator (always)

Use the `Agent` tool with `subagent_type: general-purpose`, `model: opus`. Prompt contents:

- Worktree path + `cd` instruction.
- Every file under `<staging_dir>/` as reference material (including `gap-finder.md` if it exists, and any `.failed.md` stubs).
- The diff.
- Task: for each finding across every reviewer report, decide `accept` / `modify` / `remove`:
  - `accept` — keep verbatim.
  - `modify` — rewrite when the description is unclear or overreaching, keeping the underlying issue.
  - `remove` — drop false positives. Each rejection is appended to an "Adjudicator rejections" list with a one-line reason.
- Absolute output: `<staging_dir>/adjudicated.md`. Structure: findings grouped by severity, then a "Cross-slice smells" section, then an "Adjudicator rejections" appendix.
- Read-only closing line.

## Phase R3: Reconciler (always)

Use the `Agent` tool with `subagent_type: general-purpose`, `model: opus`. The controller pre-fetched PR title/body/URL/linked-issues in Phase 0 (PR mode only) and passes them into the prompt. The reconciler *itself* fetches CI status and looks up prior reviews. Prompt contents:

- Worktree path + `cd` instruction.
- Reference files: `<staging_dir>/adjudicated.md`, the diff.
- PR metadata block (PR mode only): PR number, URL, title, body, linked issues — verbatim from Phase 0.
- Repo remote: pass `<owner>/<repo>` from `git remote get-url origin` (both modes) so the reconciler can build a compare URL and, in PR mode, call the GitHub MCP checks endpoint.
- Task: produce the single final report at absolute path `<staging_dir>/draft.md`:
  - **Summary** at top — what changed, why, and how (3–8 sentences, derived from PR body + diff shape).
  - **Links** — PR URL (PR mode); compare URL constructed as `https://github.com/<owner>/<repo>/compare/<base>...<head>`; linked issues from the PR body (PR mode); CI status via the GitHub MCP checks endpoint (PR mode only — skip in branch / SHA modes); related past reviews found by listing `<repo_root>/docs/superpowers/reviews/*.md` on the working filesystem (these are gitignored, so do not consult any git ref) and matching filenames against the current `<name>` prefix or, in PR mode, `pr-<n>.md`.
  - **Findings** — grouped by severity, then by area/file, with `file:line` + rationale.
  - **Cross-slice smells** — kept as a distinct group.
  - **Adjudicator rejections** — appendix, copied from `adjudicated.md`.
- Read-only closing line.

## Phase R4: Verifier (always)

Use the `Agent` tool with `subagent_type: general-purpose`, `model: sonnet`. Prompt contents:

- Worktree path + `cd` instruction.
- Reference files: `<staging_dir>/draft.md`, `<staging_dir>/adjudicated.md`, the diff.
- Task: check for
  - findings present in `adjudicated.md` but missing from `draft.md`,
  - contradictions between sections,
  - broken `file:line` references — for each, `grep -n <text-fragment> <file>` in the worktree to confirm the line exists and matches,
  - malformed markdown (unclosed code fences, broken tables).
  Fix issues inline in the draft. Write the corrected version to `<staging_dir>/verified.md`.
- Read-only closing line (except for the write to `verified.md`).

## Phase R5: Humanizer pass (always)

Use the `Agent` tool with `subagent_type: general-purpose`, `model: inherit`. Prompt contents:

- Worktree path + `cd` instruction (though this phase does not need git).
- Instruction: invoke the `humanizer` skill first to load its rubric, then apply it to every prose section of `<staging_dir>/verified.md`.
- Preserve code blocks, file paths, `file:line` refs, and diff quotes untouched.
- Rewrite suggestions in short plain lazy speech — as if leaving a review comment on GitHub at 5pm on a Friday.
- Write the humanized report to `<staging_dir>/final.md`.
- Read-only closing line (except for the write to `final.md`).

## Phase R6: Save and present

Copy `<staging_dir>/final.md` to `<repo_root>/docs/superpowers/reviews/<name>.md`. If the target already exists (re-run for the same name), overwrite it — no timestamping. The prior report was already picked up as a related past review by the reconciler in R3.

Print the contents of `<repo_root>/docs/superpowers/reviews/<name>.md` inline to the user.

If `final.md` is missing (any earlier phase failed catastrophically), tell the user which phase failed and skip the copy.

## Phase R7: Cleanup

Silent by default:

- Run `git worktree remove <worktree_path>` from the repo root.
- If `pr_ref_created` is true, run `git update-ref -d refs/pr/<n>` to drop the fetched PR ref.

**Ask before cleanup only when `parallel_failure` is true** (Phase 3.5 wrote a `.failed.md` stub). Sequential-phase misses are already surfaced by R6 and don't need a second escalation. Show the user the missing files and let them inspect the worktree before agreeing to remove it.
