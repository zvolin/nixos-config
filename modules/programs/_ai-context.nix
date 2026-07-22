# Client-agnostic AI assistant context, shared by the Claude Code and Codex
# global contexts. Underscore-prefixed so import-tree skips auto-discovery
# (this is a plain string, not a flake module); both default.nix files
# `import` it directly and append their own client-specific tail.
#
# The `# Shell Aliases` section below documents the `programs.zsh.shellAliases`
# in modules/programs/shell.nix (the `modern-cli` HM module) that affect
# commands you suggest the user run. Keep it in sync when those aliases
# change — shell.nix is the source of truth.
''
  # Environment

  - NixOS on Apple Silicon (Asahi kernel, aarch64-linux)
  - Tools may not be installed globally — check first, then use `nix run nixpkgs#<tool> -- <args>` to run once or `nix shell nixpkgs#<tool>` to get a shell with it
  - You cannot use sudo. Do not attempt sudo or any command requiring root.
  - This system uses impermanence — the root btrfs subvolume is wiped on every boot. /persist/ survives; /home is a separate subvolume. This repo lives at /persist/etc/nixos (symlinked to /etc/nixos).

  # Git Conventions

  IMPORTANT: These rules override default commit and merge behavior.

  - Commit messages MUST be a single line (header only): `type(scope): description`. No body, no blank line after the header, no trailers. Do NOT add `Co-Authored-By` trailers. Use `git commit -m "..."` — no HEREDOC. When a repository documents its own commit convention, follow that instead.
  - NEVER create merge commits — keep history linear (`git merge --ff-only`, `git cherry-pick`, or `git merge --squash`). If fast-forward is not possible, rebase then fast-forward.

  # Gitignored Artifacts

  docs/plans/, docs/insights/, docs/superpowers/, .claude/, .codex, .agents/, AGENTS.md, and AGENTS.override.md are globally gitignored (configured in modules/programs/git.nix). Projects that want any of these tracked must whitelist them in their own .gitignore. This keeps auto-generated docs and per-client state (settings, worktrees, agent files) out of repositories that don't use AI tooling.

  - Grep/ripgrep and glob tools skip gitignored paths by default. To find files there, use `find`, `ls`, or `rg --no-ignore-vcs`.
  - Check with `git check-ignore -q <path>` before committing. If ignored, skip the commit — do not use `git add -f`.

  # Shell Aliases

  The user's interactive zsh aliases several classic tool names to modern replacements. When you print a command for the user to paste at their zsh prompt — including when you ask them to run something and paste the output back, since you are sandboxed and sometimes need results from the real environment — the command is expanded through these aliases. So the tool you name decides two things: whether the command works, and how many tokens the pasted-back output costs you.

  **Prefer the modern tool** where classic syntax misfires under the alias:
  - `grep` → `rg --hidden --smart-case`. `rg` reads `-E` as `--encoding`, so `grep -E 'a|b'` errors instead of matching. Suggest `rg 'a|b'` (rg patterns are regex already).
  - `find` → `fd`. Different syntax: `fd PATTERN [PATH]` (no `-name`); per-match execution is `-x`/`--exec cmd {}`, not `-exec cmd {} \;`. Suggest `fd config` instead of `find . -name config`.

  **Prefer the escaped classic tool** where the modern replacement prints decorated or verbose output that wastes your context when pasted back. A leading backslash (or `command <tool>`, or an absolute path) bypasses the alias and gives you the compact, familiar GNU output:
  - `ps` → `procs`: suggest `\ps aux`. `procs` prints a wide colored table.
  - `du` → `dust`, `df` → `duf`: suggest `\du -sh` / `\df -h`, not the bar-chart or boxed-table versions.
  - `ping` → `gping`: suggest `\ping -c 4 host`. `gping` draws a live graph that never exits, so there is nothing to paste.
  - `top` / `htop` → `btop`: suggest `\top -bn1` for a one-shot snapshot. `btop` is an interactive TUI with no pasteable output.

  The list is not exhaustive. When unsure, escape with `\<tool>` to get the classic GNU tool and its compact output.

  **Scope:** none of this applies to your own Bash-tool commands, which run in non-interactive bash where these aliases do not exist — there `ps`, `grep`, `du`, and friends already resolve to the GNU tools, so use them normally (and keep using `find` / `rg --no-ignore-vcs`, as the Gitignored Artifacts section says). The aliases fire only for a command in command position at an interactive zsh prompt; a command inside a script, `zsh -c '...'`, bash, a `sudo`-prefixed call, or a Makefile already gets the original GNU tool.
''
