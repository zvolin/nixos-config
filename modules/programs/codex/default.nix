{...}: {
  flake.modules.homeManager.codex = {serena, ...}: {
    programs.codex = {
      enable = true;
      enableMcpIntegration = true;

      context = ''
        # Environment

        - NixOS on Apple Silicon (Asahi kernel, aarch64-linux)
        - Tools may not be installed globally — check first, then use `nix run nixpkgs#<tool> -- <args>` to run once or `nix shell nixpkgs#<tool>` to get a shell with it
        - You cannot use sudo. Do not attempt sudo or any command requiring root.
        - This system uses impermanence — root btrfs subvolume is wiped on every boot. /persist/ survives. /home is a separate subvolume. This repo lives at /persist/etc/nixos (symlinked to /etc/nixos).

        # Declarative Configuration

        - This is a NixOS system. To change system or user config, edit Nix files — do not create or modify dotfiles, system configs, or service files directly.
        - Home Manager is a NixOS module (not standalone). There is no `home-manager switch` command.

        # Git Conventions

        - Commit messages: single line, conventional commits format (`type(scope): description`). No body, no trailers.
        - NEVER create merge commits — keep history linear (fast-forward, cherry-pick, or squash only).

        # Gitignored Codex Artifacts

        AGENTS.md, AGENTS.override.md, .agents/, and .codex are globally gitignored (configured in modules/programs/git.nix). Repos that want any of these tracked must whitelist them in their own .gitignore. Check with `git check-ignore -q <path>` before committing; do not use `git add -f`.

        # MCP Tools

        Prefer MCP tools over CLI equivalents when available:
        - mcp-nixos for NixOS/Home Manager option lookups
        - context7 for library documentation
        - SearXNG `web_url_read` is the default URL fetcher — use it for blogs, docs, and most public URLs. For Google, Bing, DuckDuckGo, and other sites that fingerprint or rate-limit SearXNG's egress IP (for example Reddit, LinkedIn, or Cloudflare-protected SaaS), fetch the URL outside SearXNG (built-in web tools or `curl`).
        - For general search, use the built-in web search. SearXNG's `searxng_web_search` is restricted to wiki/reference engines (Wikipedia, Wikidata, GitHub, Stack Overflow, Arch/NixOS wikis, currency) — use it only when targeting those.
        - GitHub MCP for issues, PRs, code search
        - Serena (`find_symbol`, `find_referencing_symbols`, `get_symbols_overview`) for semantic code navigation in the current project
      '';

      settings = {
        model_reasoning_effort = "high";
        approval_policy = "on-request";
        projects."/home/zwolin".trust_level = "trusted";
        projects."/persist/etc/nixos".trust_level = "trusted";

        mcp_servers.serena = {
          command = "${serena}/bin/serena";
          args = ["start-mcp-server" "--context" "codex" "--project-from-cwd" "--open-web-dashboard" "false"];
          required = true;
        };
      };
    };
  };
}
