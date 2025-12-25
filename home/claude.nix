{ ... }:

{
  programs.claude-code = {
    enable = true;

    # Global CLAUDE.md instructions
    memory.text = ''
      # Environment

      - NixOS on Apple Silicon (Asahi kernel, aarch64-linux)
      - Tools may not be installed globally - use `nix run nixpkgs#<tool>` or `nix shell nixpkgs#<tool>`
      - Prefer checking if a tool exists before assuming it's installed

      # Preferences

      - Do not add Co-Authored-By to git commits
    '';

    # Settings for ~/.claude/settings.json
    settings = {
      # Plugins
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
        "superpowers@superpowers-marketplace" = true;
      };

      # Third-party plugin marketplaces
      extraKnownMarketplaces = {
        superpowers-marketplace = {
          source = {
            source = "github";
            repo = "obra/superpowers-marketplace";
          };
        };
      };

      # Experimental features
      env = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
      };

      # Global permissions (apply to all projects)
      permissions = {
        allow = [
          # Git (read-only operations)
          "Bash(git status *)"
          "Bash(git diff *)"
          "Bash(git log *)"
          "Bash(git show *)"
          "Bash(git branch *)"
          "Bash(git remote *)"
          "Bash(git fetch *)"
          "Bash(git ls-files *)"
          "Bash(git rev-parse *)"
          "Bash(git describe *)"
          "Bash(git config --get *)"
          "Bash(git config --list *)"
          "Bash(git stash list *)"
          "Bash(git blame *)"
          "Bash(git shortlog *)"

          # File listing & info
          "Bash(ls *)"
          "Bash(tree *)"
          "Bash(file *)"
          "Bash(stat *)"
          "Bash(wc *)"
          "Bash(du *)"
          "Bash(df *)"

          # Help & documentation
          "Bash(man *)"
          "Bash(* --help)"
          "Bash(* --help *)"
          "Bash(* --version)"
          "Bash(* -h)"
          "Bash(* -V)"
          "Bash(which *)"
          "Bash(whereis *)"
          "Bash(type *)"

          # Process & system info
          "Bash(ps *)"
          "Bash(pgrep *)"
          "Bash(uname *)"
          "Bash(uptime *)"
          "Bash(whoami *)"
          "Bash(id *)"
          "Bash(env *)"
          "Bash(printenv *)"

          # Notifications
          "Bash(notify-send *)"

          # Nix (read-only)
          "Bash(nix eval *)"
          "Bash(nix flake show *)"
          "Bash(nix flake metadata *)"
          "Bash(nix search *)"
          "Bash(nix-info *)"

          # GitHub CLI (read operations)
          "Bash(gh pr view *)"
          "Bash(gh pr list *)"
          "Bash(gh pr diff *)"
          "Bash(gh pr checks *)"
          "Bash(gh pr status *)"
          "Bash(gh issue view *)"
          "Bash(gh issue list *)"
          "Bash(gh issue status *)"
          "Bash(gh repo view *)"
          "Bash(gh repo list *)"
          "Bash(gh release view *)"
          "Bash(gh release list *)"
          "Bash(gh run view *)"
          "Bash(gh run list *)"
          "Bash(gh workflow view *)"
          "Bash(gh workflow list *)"
          "Bash(gh api *)"
        ]
        ++ [
          # Web access
          "WebFetch(domain:*)"
          "WebSearch"
        ];
      };

      # Hooks
      hooks = {
        Notification = [
          {
            matcher = "";
            hooks = [
              {
                type = "command";
                command = "notify-send 'Claude Code' 'Needs your attention'";
              }
            ];
          }
        ];

        PreToolUse = [
          {
            matcher = "Bash";
            matchInput = "git commit";
            hooks = [
              {
                type = "command";
                command = ''
                  diff=$(git diff --staged 2>/dev/null)
                  if [ -n "$diff" ]; then
                    review=$(echo "$diff" | codex --quiet "Review this diff for bugs, issues, and improvements. Be concise." 2>/dev/null || echo "")
                    if [ -n "$review" ]; then
                      jq -n --arg msg "**Codex Review:**"$'\n'"$review"$'\n\n'"Fix any issues before proceeding with the commit." \
                        '{"decision": "block", "reason": $msg}'
                    fi
                  fi
                '';
              }
            ];
          }
        ];

        PostToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = ''
                  cmd=$(echo "$TOOL_INPUT" | jq -r '.command // empty')
                  output=$(echo "$TOOL_RESPONSE" | jq -r '.stdout // .output // empty')
                  if [ -n "$cmd" ]; then
                    formatted=$(printf '```bash\n$ %s\n%s\n```' "$cmd" "$output")
                    jq -n --arg msg "$formatted" '{"systemMessage": $msg}'
                  fi
                '';
              }
            ];
          }
        ];

        # TODO: Fix these hooks - they slow down Claude too much currently
        # UserPromptSubmit = [
        #   {
        #     matcher = "";
        #     hooks = [
        #       {
        #         type = "prompt";
        #         blocking = false;
        #         prompt = ''
        #           Briefly note any English grammar or phrasing improvements for this message.
        #           If nothing notable, reply "none". Be concise (1-2 sentences max).
        #           Message: $ARGUMENTS
        #         '';
        #       }
        #     ];
        #   }
        # ];

        # PostToolUse = [
        #   # Code review for all code changes - catches bugs and logic issues
        #   {
        #     matcher = "Edit|Write";
        #     hooks = [
        #       {
        #         type = "prompt";
        #         prompt = ''
        #           Run the code-reviewer agent on the changes just made.
        #           File: $TOOL_INPUT
        #           Be concise - only report actual issues found.
        #         '';
        #       }
        #     ];
        #   }
        #   # Security audit for sensitive files
        #   {
        #     matcher = "Edit|Write";
        #     matchInput = "(auth|login|password|secret|token|crypto|key|credential|session|cookie|jwt|oauth|permission|access|security|\.env|config)";
        #     hooks = [
        #       {
        #         type = "prompt";
        #         prompt = ''
        #           Run the security-auditor agent on this security-sensitive file.
        #           File: $TOOL_INPUT
        #           Only report exploitable vulnerabilities, not theoretical risks.
        #         '';
        #       }
        #     ];
        #   }
        #   # Test checker when test files are modified
        #   {
        #     matcher = "Edit|Write";
        #     matchInput = "(test|spec|_test\.|\.test\.|tests/)";
        #     hooks = [
        #       {
        #         type = "prompt";
        #         prompt = ''
        #           Run the test-checker agent to verify tests are valid.
        #           File: $TOOL_INPUT
        #           Check test quality and coverage gaps.
        #         '';
        #       }
        #     ];
        #   }
        #   # Architecture review for new files and changes
        #   {
        #     matcher = "Edit|Write";
        #     hooks = [
        #       {
        #         type = "prompt";
        #         prompt = ''
        #           Run the code-architect agent on this file.
        #           File: $TOOL_INPUT
        #           Check for over-engineering and unnecessary complexity.
        #         '';
        #       }
        #     ];
        #   }
        # ];
      };
    };

    # MCP servers
    # mcpServers = {
    #   filesystem = {
    #     command = "npx";
    #     args = [ "-y" "@anthropic/mcp-filesystem-server" "/home/zwolin" ];
    #   };
    # };

    # Custom slash commands (stored in ~/.claude/commands/)
    # commands = {
    #   commit = ''
    #     ---
    #     allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*)
    #     description: Create a git commit with proper message
    #     ---
    #     ## Context
    #
    #     - Current git status: !`git status`
    #     - Current git diff: !`git diff HEAD`
    #     - Recent commits: !`git log --oneline -5`
    #
    #     ## Task
    #
    #     Based on the changes above, create a single atomic git commit with a descriptive message.
    #   '';
    # };

    # Custom agents (stored in ~/.claude/agents/)
    agents = {
      code-reviewer = ''
        ---
        name: code-reviewer
        description: Use after code changes to review quality and catch bugs
        tools: Read, Grep, Glob, Bash
        model: sonnet
        ---

        You are a pedantic code reviewer who catches bugs before they ship.

        **Logic bugs - the silent killers:**
        - Off-by-one errors in loops and slices
        - Null/None/empty handling - what happens when the list is empty?
        - Integer overflow - u32 arithmetic in blockchain code is a CVE waiting to happen
        - Race conditions - shared state without synchronization
        - Resource leaks - opened files, connections, locks not released on error paths

        **Rust-specific footguns:**
        - `.unwrap()` in library code - use `?` or proper error handling
        - `.clone()` hiding ownership issues - is this clone actually needed?
        - `&String` instead of `&str`, `&Vec<T>` instead of `&[T]`
        - Missing `#[must_use]` on Result-returning functions
        - Panics in `Drop` implementations

        **Nix-specific:**
        - `with pkgs;` polluting scope - prefer explicit `pkgs.foo`
        - Import-from-derivation (IFD) slowing down evaluation
        - `rec {}` when `let ... in` works
        - Unused function arguments not prefixed with `_`

        Run `git diff HEAD~1` to review recent changes. Be specific: "line 42: this unwrap panics if X is empty".
      '';

      security-auditor = ''
        ---
        name: security-auditor
        description: Use to audit code for security vulnerabilities before merge
        tools: Read, Grep, Glob, Bash
        model: sonnet
        ---

        You are a paranoid security auditor. Assume attackers are clever.

        **Injection - trust nothing external:**
        - Command injection - string interpolation into shell commands
        - Path traversal - `../` in user-provided paths, symlink attacks
        - SQL injection - string concatenation in queries
        - Template injection - user input in format strings

        **Secrets - grep for them:**
        - Hardcoded API keys, tokens, passwords (check git history too)
        - Private keys committed, even "for testing"
        - .env files not in .gitignore
        - Secrets logged or in error messages

        **Crypto sins:**
        - Rolling your own crypto - don't
        - Weak randomness - `rand::random()` for crypto (use `rand::rngs::OsRng`)
        - Hardcoded IVs/nonces
        - MD5/SHA1 for security purposes

        **Rust-specific:**
        - `unsafe` blocks - each one needs justification
        - `std::mem::transmute` - almost always wrong
        - Raw pointer arithmetic
        - FFI boundary issues

        Rate findings: CRITICAL (exploit now) / HIGH (needs fix before merge) / MEDIUM (fix soon) / LOW (hardening).
        No theoretical risks - only report what's actually exploitable.
      '';

      test-checker = ''
        ---
        name: test-checker
        description: Use to verify tests pass and coverage after changes
        tools: Read, Grep, Glob, Bash
        model: sonnet
        ---

        You verify tests actually protect against regressions.

        **Run the damn tests:**
        - `cargo test` for Rust
        - `nix flake check` for Nix
        - Check CI config for what else should run

        **Coverage reality check:**
        - New functions without tests? Flag them.
        - Tests that don't assert anything meaningful? "assert!(true)" is not a test.
        - Error paths untested? Happy path only is 50% coverage at best.
        - Edge cases: empty input, max values, unicode, concurrent access.

        **Test quality:**
        - Tests that duplicate implementation - will pass even if both are wrong
        - Flaky tests - timing dependencies, global state, network calls
        - Tests that take forever - likely doing too much
        - Missing test for the bug that was just fixed

        **Output format:**
        ```
        TESTS: PASS / FAIL (N failures)
        COVERAGE GAPS:
        - path/to/file.rs:42 - `process_payment` has no tests
        - path/to/file.rs:87 - error handling branch untested
        ISSUES:
        - test_foo is flaky (uses sleep)
        ```
      '';

      code-architect = ''
        ---
        name: code-architect
        description: Use to review architecture and fight over-engineering
        tools: Read, Grep, Glob, Bash
        model: sonnet
        ---

        You are a pragmatic architect who values simplicity. Review code for:

        **Kill complexity:**
        - Premature abstractions - "will we ever need this?"
        - Unnecessary indirection - wrapper types, excessive traits/interfaces
        - Speculative generality - YAGNI violations
        - Over-engineered patterns - factories, builders, visitors where simple code works

        **Keep it maintainable:**
        - DRY violations - actual duplication (3+ occurrences), not coincidental similarity
        - Clear module boundaries - cohesion within, loose coupling between
        - Obvious code paths - can a new dev follow this in 5 minutes?

        **Rust-specific:**
        - Trait bloat - too many traits for simple behavior
        - Excessive generics - when concrete types suffice
        - Macro overuse - when functions work fine

        Be direct. "Delete this abstraction" is valid feedback. Three lines of similar code is often better than a premature helper.
      '';

      change-summary = ''
        ---
        name: change-summary
        description: Use to summarize changes for commits or PRs
        tools: Read, Grep, Glob, Bash
        model: haiku
        ---

        You write commit messages using Conventional Commits.

        **Gather context:**
        - `git diff --stat` - what files changed
        - `git diff` - actual changes

        **Format:**
        ```
        <type>[scope][!]: <description>

        [Fixes #N | Closes #N]
        ```

        **Types:** feat, fix, refactor, docs, test, chore, perf, ci

        **Breaking changes:** Add `!` after type/scope: `feat(api)!: remove endpoint`

        **Rules:**
        - Subject: imperative mood, <50 chars, no period
        - NO body unless user asks for explanation
        - Only footer: issue refs or one-line breaking change note
        - One logical change = one commit

        **Examples:**
        ```
        feat(auth): add OAuth2 login
        ```

        ```
        fix(parser)!: reject invalid UTF-8

        Fixes #567
        ```
      '';
    };
  };
}
