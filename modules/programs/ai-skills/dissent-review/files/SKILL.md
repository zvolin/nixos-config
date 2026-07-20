---
name: dissent-review
description: Auto-triggered adversarial review of a spec, plan, or wayfinder map. Dispatches a cold dissent reviewer, collects the main agent's honest responses, then a neutral adjudicator decides each finding apply/skip/ask. Invoked as a sub-step by brainstorming, writing-plans, and wayfinder.
---

# Dissent Review

You are running the dissent-review sub-step for the surface skill that invoked you. A cold reviewer argues the strongest honest case against the artifact; you, the main agent, answer each finding honestly; a neutral adjudicator decides what to do. You then fold the outcomes back into the artifact. The main agent is a cooperative, honest participant here — the failure mode this guards against is an honest blind spot, not a lie, so you keep a voice and the neutral third party judges between you and the dissenter.

**Announce at start:** "Running dissent-review on `<path>` (artifact=<type>)."

## Inputs

The surface passes:
- `artifact` — one of `spec`, `plan`, `map`.
- `path` — the artifact file to review.
- For `artifact=map` only: the raw values wayfinder holds — destination (verbatim), chart state (`charted` or `re-chartered`), closed-ticket ids, tracker bindings, and `review scope` (the region to review: `whole map + all new tickets` at chart time, or `changed region: <ticket id> plus tickets it added or altered` at resolution time). These fill the named slots in the map lens block, and the reviewer confines its findings to `review scope`.

## Locate the prompt files

Read the two prompt files that sit next to this `SKILL.md` (co-located — do not hardcode any absolute path; this skill installs to a hashed store path):
- `dissent-reviewer-prompt.md`
- `adjudicator-prompt.md`

## Phase 1: Dispatch the dissent reviewer

Fill the dissent template from `dissent-reviewer-prompt.md`: pick the lens block matching `artifact`, and for `map` fill the named value slots from the raw values. Dispatch it with the `Agent` tool, `subagent_type: general-purpose`. Pass only the artifact contents (read `path`) and the filled prompt. NEVER pass the authoring conversation — session history is the blind spot this review exists to escape.

- spec / plan: one dissent subagent.
- map: one dissent subagent, given all three lenses as its rubric.

It returns a ranked findings list, or a one-line `sound:` verdict.

**Sound artifact:** if it returns `sound:`, phases 2–4 are no-ops. Report "dissent found the artifact sound" and return.

**Reviewer died or returned malformed output:** do NOT treat this as "no findings" — that ships an un-reviewed artifact while the user believes it was reviewed. Surface a loud notice — `dissent did NOT run on <path>: <reason>` — and return so the surface's own review gate shows it. This is the `.failed.md` posture the `review` skill uses.

## Phase 2: Main agent honest responses

Back in the main context, write a brief honest response to each finding: concede, disagree (with reasoning), or supply context the finding lacks (for example, "this was deliberately scoped out because Y"). Be humble and non-defensive — take the real hits, and don't manufacture agreement or disagreement. An honest opinion is enough. This is an input to the adjudicator; you do NOT resolve your own case here.

## Phase 3: Dispatch the adjudicator

Fill the adjudicator template from `adjudicator-prompt.md`. Dispatch with the `Agent` tool, `subagent_type: general-purpose`, blind to the authoring conversation. Pass the artifact contents, the dissent findings, and your honest responses. It may read cited source material and the codebase. It rules on the whole list in one pass — one outcome per finding: `apply`, `skip`, or `ask`.

## Phase 4: Fold back

Carry out the adjudicator's outcomes:

- **apply** → make the edit directly in `path`. (For a map, see Advisory maps below — recommend, don't edit tracker state.)
- **skip** → log one line in a rejections appendix shown to the human: "dissent raised X, no change because Y."
- **ask** → escalate to the human with the finding, your honest response, and the adjudicator's note; wait. The user has not seen the artifact's shape yet, so carry all the context — the background and both views — so they can decide. There is no autonomous shape-rewrite loop: a change big enough to restructure the artifact goes to the human, never applied and re-reviewed by the machine.

Present to the human the `ask` findings and the skimmable rejections appendix. Applied changes show up in the artifact at the surface's own review gate. If the adjudicator marks every finding `ask`, that is fine — it degrades to "present all findings to the human," which is never worse than a manual deep review.

### Advisory maps

For `artifact=map` the fold-back does NOT autonomously edit live tracker state (ticket frontmatter, blocking edges) — that would collide with the sessions wayfinder runs concurrently. `apply` means "recommend this edit," not "make it silently." Surface the outcomes; the main agent folds them into the map through wayfinder's normal resolution flow (structural fixes applied, decisions recorded, forks to the human).

## Return

Return control to the surface skill. The surface runs its own conformance lint next, then a final `humanizer` pass — neither is part of this skill.
