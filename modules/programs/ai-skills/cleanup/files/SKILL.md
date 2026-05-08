---
description: Clean up code in current branch - simplify, remove AI artifacts, challenge decisions
---

Review and clean up all added/changed code in the current git branch compared to main.

**Steps:**

1. Get the diff: `git diff main...HEAD` to see all changes
2. Read surrounding code in the same files/modules to understand existing patterns
3. For each changed file, analyze the code for:

**Remove:**
- Unnecessary comments (obvious ones, TODOs that are done, redundant explanations)
- AI-generated artifacts ("Here's the implementation", "This function does X", excessive docstrings)
- Over-engineered abstractions that add complexity without value
- Unused imports, variables, or dead code
- Redundant error handling or validation

**Simplify:**
- Extract overly nested logic
- Combine duplicate code paths
- Reduce function parameters where possible
- Remove unnecessary intermediate variables

**Make Idiomatic:**
- Replace verbose patterns with language-specific idioms
- Use standard library functions where applicable
- Follow the conventions of the existing codebase
- Match naming style, error handling patterns, and structure of surrounding code

**Check Consistency:**
- Compare with similar code elsewhere in the repo
- Ensure new code matches existing patterns for the same operations
- Flag any deviations from established conventions

**Security Review:**
- Input validation and sanitization
- Injection vulnerabilities (SQL, command, path traversal)
- Authentication/authorization gaps
- Sensitive data exposure
- Race conditions or unsafe concurrency

**Performance:**
- Obvious inefficiencies (N+1 queries, unnecessary loops, repeated computations)
- Unnecessary allocations or copies

**Error Handling:**
- Are errors informative and actionable?
- Proper error propagation (not swallowing errors silently)

**Naming:**
- Are names clear and descriptive?
- Consistent with domain terminology?

**Dependencies:**
- Any unnecessary new dependencies introduced?
- Could use existing utilities instead?

**Challenge:**
- Is this abstraction necessary or premature?
- Could this be done more simply?
- Are there edge cases not handled?
- Does this duplicate existing functionality?

4. Present a brief summary of potential improvements grouped by category
5. Let the user decide which changes to apply — do NOT make edits automatically
