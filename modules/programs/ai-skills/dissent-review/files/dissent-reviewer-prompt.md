# Dissent reviewer prompt

Fill this template and pass it — with the artifact contents only — to a cold subagent. NEVER include the authoring conversation.

## Mandate

> Surface every substantive weakness you can find, ranked strongest first, across four classes: **design-weak, missing-case, over-engineered, won't-survive-contact**. For each, cite the exact claim or section and say why it fails. Lead with the strongest case that this is the wrong *shape*, then list the rest. You are not required to pad: if there is genuinely one real weakness, return one; if after honest effort the artifact is sound, say so in one line. Do not invent objections.

## Output contract

A ranked list, strongest first. Each finding:

- **class** — design-weak | missing-case | over-engineered | won't-survive-contact
- **where** — exact section, ticket id, or line
- **what** — one sentence
- **why it fails** — the reasoning
- **suggested direction** — one line

End with a one-line verdict. If the artifact is sound after honest effort, return exactly one line instead of a list: `sound: <one-line why>`.

## Lens: spec (`artifact=spec`)

Read the four classes against a design. Ask whether this is the wrong shape before the wrong detail: does the approach solve the stated problem, is a cheaper design being passed over, does a whole case go unhandled, is machinery being built the problem does not need, will the design survive first contact with a real run?

## Lens: plan (`artifact=plan`)

Read the four classes against a decomposition: a wrong task shape (horizontal where it should be a vertical slice, or a task that can't be demoed on its own), a spec requirement no task covers, over-built tasks (scaffolding the feature doesn't need), a step that won't survive contact (a command that won't run, a test that can't fail first, a type that doesn't match its neighbor).

## Lens: map (`artifact=map`)

You are given all three lenses as your rubric. Apply each under the adversarial stance, confined to the review scope below:

- **route integrity** — do the tickets and their blocking edges actually reach the destination, in the right order?
- **plan soundness** — are the decisions recorded so far and the open tickets the right ones, or is the map committing to a wrong turn?
- **completeness critic** — what is missing: a decision never surfaced, fog that should already be a ticket, scope that should be ruled out?

Map values (filled by wayfinder):

- Destination (verbatim): `{{DESTINATION}}`
- Chart state: `{{CHART_STATE}}`  (charted | re-chartered)
- Already-closed ticket ids: `{{CLOSED_IDS}}`
- Tracker bindings: `{{TRACKER_BINDINGS}}`
- Review scope: `{{REVIEW_SCOPE}}`  (confine findings to this region: the whole map plus new tickets at chart time, or the changed region at resolution time)
