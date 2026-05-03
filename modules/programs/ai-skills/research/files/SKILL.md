---
name: research
description: Research a topic or question from multiple angles with web search, parallel expansion review, and self-review. Produces a markdown report. Use when the user asks to research, investigate, look into, or learn about a topic.
---

# Research

Investigate a topic from several angles. After the first investigation pass, dispatch a parallel pair of subagent reviewers — one hunting for missed alternatives, one challenging the proposed options against real-world opinions and weak points. Optionally repeat that pair once. Then synthesize prose and run the existing draft reviewer as the prose quality gate.

**Announce at start:** "Using the research skill to investigate <topic>."

## Tool mapping

| Action | Claude Code | Codex |
|---|---|---|
| Web search | `WebSearch` | built-in web search |
| Read URL | SearXNG `web_url_read` (preferred), fallback `WebFetch` | built-in web fetch |
| Read local files | `Read`, `Grep`, Serena (`find_symbol` etc.) | `Read`, `Grep`, Serena |
| Dispatch reviewer | `Agent` tool (general-purpose subagent) | Codex subagent |

## Phases

### 1. Intake

Ask clarifying questions one at a time. Cap at 3-4. Skip when the topic is already specific. Accept "just go" or similar as an immediate exit.

Typical questions: scope (academic vs practitioner), audience (background level), time horizon, what existing knowledge to assume.

### 2. Project relevance

Test: does the topic name a tech, library, concept, or pattern the current repo uses? If yes, mark which facets benefit from local file inspection. If no, web-only.

### 3. Plan: 3-7 facets

Pick distinct angles. Per-option weak points and dissent are covered by the validation reviewer in phase 8 — you don't need a dedicated dissent facet.

Angle hints, pick what fits:
- Programming / CS: how-it-works, practitioner experience, criticisms, alternatives, history.
- Books / media recs: well-regarded, overrated, lesser-known, adjacent topics, critical reception.
- Historical / factual: primary sources, scholarly consensus, revisionist views.
- Decisions / comparisons: pros, cons, hidden tradeoffs, what experienced people pick.
- "What should I learn next" type: case for, case against, prerequisites, what comes after.

### 4. Plan self-review (in-context)

Single critique pass. Checklist:
- Are angles genuinely distinct, or are two of them basically the same?
- Are there obvious gaps for the topic type?

If any check fails, revise once and re-check. Cap at one revision — if the second draft still fails, ship it with the unresolved gaps noted in a one-line self-review summary. Show the user only the post-revision version.

### 5. User confirms plan

Mandatory checkpoint. The user can edit, drop, or add facets. Wait for OK before investigating.

### 6. Investigate

For each facet:
- Web search → URL read for the most promising sources.
- Light counter-evidence sweep ("X criticisms", "problems with X", "X overrated") — enough to fill preliminary cons in the bullet draft.
- For project-relevant facets: also read the relevant local files.

Collect quotes, URLs, and per-facet preliminary cons as you go.

### 7. Bullet-form tentative draft

Internal scratch — not shown to the user. Assemble a structured list per facet:

```
## Facet: <title>
- What it is: <one sentence>
- What it gives / implies / achieves: <one sentence>
- Pros / tradeoffs:
  - ...
- Cons / limitations:
  - ...
- Sources used: <urls>
```

This is the input to phase 8.

### 8. Expansion review (parallel subagents)

Dispatch two subagents in parallel against the bullet draft.

**Coverage reviewer.** Inputs: original question, plan, bullet draft, list of URLs already consulted. Job: find missed niche alternatives. Has web access. Reviewer prompt at `coverage-reviewer-prompt.md` (next to this file).

**Validation reviewer.** Inputs: original question, plan, bullet draft. Job: validate options against real-world opinions and weak points. Has web access. Reviewer prompt at `validation-reviewer-prompt.md` (next to this file).

### 9. Integrate findings

Update the bullet draft:
- New options from coverage become new facet entries (or attach to existing facets per the reviewer's "Target facet" suggestion).
- Validation findings go into the relevant facet's cons. Topic-wide criticism gets collected separately for the conditional standalone "Dissenting views" section.
- For new options needing preliminary investigation: 1-2 most promising sources per option, no full counter-evidence sweep at this stage.

### 10. 2nd round decision

Run a 2nd round of phase 8 when:
- Coverage round 1 surfaced new options that haven't been validated.
- Validation round 1 surfaced criticisms that point to new options worth coverage-checking.
- The bullet draft changed substantively (new facets added, existing facets significantly reframed).

Counter-example — do not run round 2 when coverage returned "no genuine misses" and validation only contributed per-option weak points without surfacing new options. That's already a complete pass.

If none of the round-2 triggers apply, skip to phase 11. Hard cap: 2 rounds total.

### 11. Synthesize prose draft

Expand the bullet draft into the full prose report using the output template below.

### 12. Subagent review (fresh context)

Dispatch the existing draft reviewer with: the prose draft, the original question, the intake assumptions, and the plan. Reviewer prompt at `reviewer-prompt.md` (next to this file). Returns:
- **Critical:** factual errors, unsupported claims, scope drift, internal contradictions.
- **Suggested:** weak phrasing, unclear sections, citations to add.
- **Nit:** style nits.

### 13. Revise

Apply all critical findings. Apply most suggested. Skip nits unless trivial. Loop back to phase 12 until zero critical findings, hard cap **5 review rounds total**.

If the cap is hit without approval, do **not** silently save. Surface to the user the recurring unresolved findings and three choices: (a) save as-is and accept the gaps, (b) hand back for manual edits, (c) abort and discard.

### 14. Humanizer pass

Run the `humanizer` skill on the prose (TL;DR, facet sections, conditional dissent section). Skip code blocks, file paths, URLs, structured lists.

### 15. Save

Write to `docs/research/YYYY-MM-DD-<slug>.md` if in a git repo; otherwise ask. Do not auto-commit.

## Output template

```markdown
# <Title>

**Question:** <verbatim user request>
**Assumptions made during intake:** <bullets, or "none">
**Date:** YYYY-MM-DD

## TL;DR
- 3-5 bullets, one line each

## Quick overview
- <Facet 1 title> — one-sentence essence
- <Facet 2 title> — one-sentence essence

## <Facet 1 title>

**What it is:** 2-4 sentences.

**What it gives / implies / achieves:** 2-4 sentences. Wording adapts to the topic — for option-shaped facets this is "what choosing it gets you"; for explanation-shaped facets it's "what this enables / what follows from it".

**Pros / tradeoffs:**
- ...

**Cons / limitations:**
- ...

A reasoning paragraph that ties the four parts together with inline citations [^N]. This is where the agent argues — why these pros matter for the use case, what the cons rule out, where this option fits among the others.

## <Facet 2 title>
... same structure ...

## Dissenting views (conditional)

Present only when the validation reviewer surfaced topic-wide criticism that doesn't fit any single facet's cons. Drop the section entirely when there is nothing to put here.

## Open questions / could not verify
- <gaps the reviewer flagged that didn't get resolved>

## Sources
[^1]: <Title> — <URL>
[^2]: <Title> — <URL>
```
