{ ... }:

let
  # synthetic plugin name from home-manager claude-code module
  mcpPrefix = "mcp__plugin_claude-code-home-manager";
  ferrex = tool: "${mcpPrefix}_ferrex__${tool}";
  serena = tool: "${mcpPrefix}_serena__${tool}";
in
{
  programs.claude-code.settings.permissions = {
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
      "Bash(git worktree *)"
      "Bash(git grep *)"
      "Bash(git ls-tree *)"
      "Bash(git cat-file *)"
      "Bash(git for-each-ref *)"
      "Bash(git rev-list *)"
      "Bash(git merge-base *)"
      "Bash(git reflog *)"
      "Bash(git tag *)"
      "Bash(git ls-remote *)"
      "Bash(git cherry *)"
      "Bash(git range-diff *)"
      "Bash(git submodule status *)"

      # File listing & info
      "Bash(ls *)"
      "Bash(tree *)"
      "Bash(file *)"
      "Bash(stat *)"
      "Bash(wc *)"
      "Bash(du *)"
      "Bash(df *)"
      "Bash(head *)"
      "Bash(tail *)"
      "Bash(col *)"
      "Bash(grep *)"
      "Bash(rg *)"
      "Bash(find *)"
      "Bash(fd *)"
      "Bash(cat *)"
      "Bash(bat *)"
      "Bash(eza *)"
      "Bash(readlink *)"
      "Bash(realpath *)"
      "Bash(basename *)"
      "Bash(dirname *)"

      # Text processing
      "Bash(sort *)"
      "Bash(uniq *)"
      "Bash(cut *)"
      "Bash(tr *)"
      "Bash(diff *)"
      "Bash(sed *)"
      "Bash(awk *)"
      "Bash(jq *)"
      "Bash(column *)"
      "Bash(strings *)"
      "Bash(xargs *)"

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
      "Bash(printenv *)"
      "Bash(date *)"
      "Bash(hostname *)"
      "Bash(free *)"

      # Notifications
      "Bash(notify-send *)"

      # Nix
      "Bash(nix eval *)"
      "Bash(nix flake show *)"
      "Bash(nix flake metadata *)"
      "Bash(nix flake check *)"
      "Bash(nix search *)"
      "Bash(nix build *)"
      "Bash(nix fmt *)"
      "Bash(nix run *)"
      "Bash(nix shell *)"
      "Bash(nix develop *)"
      "Bash(nix-info *)"
      "Bash(nix-instantiate *)"
      "Bash(nix-store *)"
      "Bash(nixos-rebuild *)"
      "Bash(alejandra *)"
      "Bash(deadnix *)"
      "Bash(statix *)"

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
      "Bash(gh status *)"
      "Bash(gh search *)"
      "Bash(gh auth status *)"
      "Bash(gh label *)"

      # Build & test
      "Bash(cargo *)"
      "Bash(npm test *)"
      "Bash(npm run *)"
      "Bash(make *)"
      "Bash(just *)"
      "Bash(cmake *)"

      # AI
      "Bash(codex *)"
    ]
    ++ (map ferrex [
      # Read-only
      "recall"
      "reflect"
      "stats"
      "taxonomy"
      "timeline"
    ])
    ++ (map serena [
      # Read-only
      "find_symbol"
      "find_referencing_symbols"
      "get_symbols_overview"
      "find_file"
      "list_dir"
      "search_for_pattern"
      "get_current_config"
      "check_onboarding_performed"
      "initial_instructions"
      "list_memories"
      "read_memory"
      "activate_project"
      "open_dashboard"
      "onboarding"
    ])
    ++ [
      # Skill auto-invocation
      "Skill(recall)"
      "Skill(reflect)"
    ]
    ++ [
      # Web access
      "Bash(curl *)"
      "WebFetch"
      "WebSearch"
    ];
  };
}
