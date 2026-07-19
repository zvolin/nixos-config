# Client-agnostic AI assistant context, shared by the Claude Code and Codex
# global contexts. Underscore-prefixed so import-tree skips auto-discovery
# (this is a plain string, not a flake module); both default.nix files
# `import` it directly and append their own client-specific tail.
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
''
