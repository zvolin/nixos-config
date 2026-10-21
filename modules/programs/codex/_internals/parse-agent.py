#!/usr/bin/env python3
"""Parse a Claude-format agent .md into the Codex agent value object (as JSON).

This runs at BUILD time inside the agent-toml derivation, so the source is a
plain build input and is never read during Nix evaluation — which is what keeps
a derivation-backed agent source from triggering import-from-derivation. The
emitted JSON is handed to the same `json2x toml` converter that
`pkgs.formats.toml` uses, so the generated TOML is byte-identical to the former
eval-time `tomlFormat.generate` path.

Semantics mirror the previous Nix implementation exactly:
  * source must start with `---\n`; otherwise it is rejected.
  * frontmatter is the fixed `key: value` block between the first two `---`
    markers, parsed with the regex `([a-zA-Z_-]+): (.*)`; non-matching lines are
    dropped and the first occurrence of a duplicate key wins.
  * model map: opus,sonnet -> gpt-5.6; haiku -> gpt-5.6-terra; any other (or
    missing) claude model -> gpt-5.6. `model` is emitted only when the
    frontmatter carries a `model:` key.
  * reasoning effort = reasoning_effort else effort else "medium"; any value
    outside {low,medium,high} clamps to "high".
  * `description` is required.
"""

import json
import re
import sys

# Claude frontmatter `model:` -> Codex model tier. `sonnet` means "as cheap as
# safe": Codex has no mid tier, so it rounds `sonnet` up to the top tier. That is
# a faithful rendering of "not cheap", not a leak -- `terra` is the deliberately-
# declined weak-implementer risk. opus also lands on the top tier; haiku maps to
# the lighter `terra` tier. When a mid Codex tier ships, add one line here and
# every `sonnet` agent cheapens automatically.
MODEL_MAP = {"opus": "gpt-5.6", "sonnet": "gpt-5.6", "haiku": "gpt-5.6-terra"}
DEFAULT_CODEX_MODEL = "gpt-5.6"
CODEX_EFFORTS = {"low", "medium", "high"}
FRONTMATTER_GUARD = "---\n"
FRONTMATTER_SEP = "\n---\n"
LINE_RE = re.compile(r"([a-zA-Z_-]+): (.*)")


def parse_frontmatter_and_body(src: str, name: str) -> tuple[dict[str, str], str]:
    if not src.startswith(FRONTMATTER_GUARD):
        raise SystemExit(
            "programs.codex.agents: source does not start with `---\\n` "
            "frontmatter delimiter"
        )
    after_open = src[len(FRONTMATTER_GUARD):]
    splits = after_open.split(FRONTMATTER_SEP)
    frontmatter = splits[0]
    body = FRONTMATTER_SEP.join(splits[1:])
    if body.startswith("\n"):
        body = body[1:]

    fm: dict[str, str] = {}
    for line in frontmatter.split("\n"):
        match = LINE_RE.fullmatch(line)
        if match is None:
            continue
        key, value = match.group(1), match.group(2)
        # First occurrence wins, matching Nix `builtins.listToAttrs`.
        fm.setdefault(key, value)
    return fm, body


def build_value(name: str, fm: dict[str, str], body: str) -> dict[str, str]:
    if "description" not in fm:
        raise SystemExit(
            f"programs.codex.agents.{name}: frontmatter is missing required "
            "`description` key"
        )
    raw_effort = fm.get("reasoning_effort", fm.get("effort", "medium"))
    reasoning_effort = raw_effort if raw_effort in CODEX_EFFORTS else "high"

    value = {
        "name": name,
        "description": fm["description"],
        "developer_instructions": body,
        "model_reasoning_effort": reasoning_effort,
    }
    if "model" in fm:
        value["model"] = MODEL_MAP.get(fm["model"], DEFAULT_CODEX_MODEL)
    return value


def main() -> None:
    source_path, name = sys.argv[1], sys.argv[2]
    with open(source_path, encoding="utf-8") as handle:
        src = handle.read()
    fm, body = parse_frontmatter_and_body(src, name)
    value = build_value(name, fm, body)
    # Sorted keys so the JSON object order matches Nix's structured-attrs
    # serialization, keeping json2x output identical.
    json.dump(value, sys.stdout, sort_keys=True, ensure_ascii=False)


if __name__ == "__main__":
    main()
