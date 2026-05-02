---
name: research
description: Research a topic or question from multiple angles with web search, counter-evidence hunt, and self-review. Produces a markdown report. Use when the user asks to research, investigate, look into, or learn about a topic.
---

# Research

Investigate a topic from several angles, deliberately hunt for counter-evidence, self-review the plan and final draft, then save a markdown report.

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

Ask clarifying questions one at a time. Cap at 3–4. Skip when the topic is already specific. Accept "just go" or similar as an immediate exit.

Typical questions: scope (academic vs practitioner), audience (background level), time horizon, what existing knowledge to assume.

### 2. Project relevance

Test: does the topic name a tech, library, concept, or pattern the current repo uses? If yes, mark which facets benefit from local file inspection. If no, web-only.

### 3. Plan: 3–7 facets

Pick distinct angles. **At least one facet must be dissent-shaped** — criticisms, overrated picks, dissenting views, failure modes. Wording varies by topic.

Angle hints, pick what fits:
- Programming / CS: how-it-works, practitioner experience, criticisms, alternatives, history.
- Books / media recs: well-regarded, overrated, lesser-known, adjacent topics, critical reception.
- Historical / factual: primary sources, scholarly consensus, revisionist views.
- Decisions / comparisons: pros, cons, hidden tradeoffs, what experienced people pick.
- "What should I learn next" type: case for, case against, prerequisites, what comes after.

### 4. Plan self-review (in-context)

Single critique pass. Checklist:
- Are angles genuinely distinct, or are two of them basically the same?
- Is dissent represented?
- Are there obvious gaps for the topic type?

If any check fails, revise once and re-check. Cap at one revision — if the second draft still fails, ship it with the unresolved gaps noted in a one-line self-review summary. Show the user only the post-revision version.

### 5. User confirms plan

Mandatory checkpoint. The user can edit, drop, or add facets. Wait for OK before investigating.

### 6. Investigate

For each facet:
- Web search → URL read for the most promising sources.
- For non-dissent facets: also a brief counter-evidence sweep ("X criticisms", "problems with X", "X overrated").
- For project-relevant facets: also read the relevant local files.

Collect quotes and URLs as you go.

### 7. Synthesize

Write the first markdown draft using the output template below.

### 8. Subagent review (fresh context)

Dispatch a reviewer with: the draft, the original question, the intake assumptions, and the plan. Reviewer prompt template lives at `reviewer-prompt.md` next to this file. The reviewer returns structured findings:
- **Critical:** factual errors, unsupported claims, missing dissent, scope drift.
- **Suggested:** weak phrasing, unclear sections, citations to add.
- **Nit:** style nits.

### 9. Revise

Apply all critical findings. Apply most suggested. Skip nits unless trivial. Loop back to step 8 until zero critical findings, hard cap **5 review rounds total**.

If the cap is hit without approval, do **not** silently save. Surface to the user the recurring unresolved findings and three choices: (a) save as-is and accept the gaps, (b) hand back for manual edits, (c) abort and discard.

### 10. Humanizer pass

Run the `humanizer` skill on the prose (sections, TL;DR, dissent section). Skip code blocks, file paths, URLs, structured lists.

### 11. Save

Write to `docs/research/YYYY-MM-DD-<slug>.md` if in a git repo; otherwise ask. Do not auto-commit.

## Output template

```markdown
# <Title>

**Question:** <verbatim user request>
**Assumptions made during intake:** <bullets, or "none">
**Date:** YYYY-MM-DD

## TL;DR
- 3-5 bullets

## <Facet 1>
... text with inline numeric citations [^1] ...

## <Facet 2>
...

## Dissenting views
(may rename to fit topic — e.g. "Critical reception", "Overrated picks", "Known failure modes")
- ...

## Open questions / could not verify
- <gaps the reviewer flagged that didn't get resolved>

## Sources
[^1]: <Title> — <URL>
[^2]: <Title> — <URL>
```
