{ ... }:
let
  aiSharedContext = import ../_ai-context.nix;
in
{
  flake.modules.homeManager.claude =
    { config, lib, ... }:
    let
      # Last claude-code version whose model aliases were verified against the
      # ANTHROPIC_DEFAULT_*_MODEL pins below. Bump it after re-checking the IDs.
      lastVerifiedVersion = "2.1.224";
      claudeVersion = config.programs.claude-code.package.version;
    in
    {
      imports = [
        ./_internals/agents.nix
        ./_internals/skills.nix
        ./_internals/hooks.nix
        ./_internals/mcp.nix
        ./_internals/permissions.nix
        ./_internals/marketplace.nix
        ./_internals/rules.nix
        ./_internals/statusline.nix
        ./_internals/sandbox.nix
        ./_internals/security.nix
        ./_internals/preferences.nix
      ];

      programs.claude-code = {
        enable = true;

        # Global CLAUDE.md instructions
        context = ''
          ${aiSharedContext}

          # Publishing Artifacts

          HARD-GATE: the Artifact tool uploads to claude.ai (Anthropic servers). Propose publishing an artifact when it genuinely helps, but NEVER publish one without the user's explicit consent.

          # MCP Tools

          Prefer MCP tools over their CLI/built-in equivalents:
          - mcp-nixos (`nix` tool) over `nixos-option` or `man` for NixOS, Home Manager, nix-darwin, and nixvim options.
          - context7 (`resolve-library-id`, then `get-library-docs`) for library documentation before guessing at APIs.
          - Use `gh` (already installed and authenticated) for GitHub PRs, issues, and code search — `gh --json` gives structured output.

          # After Completing Code

          - Run `/cleanup` to review changes for AI artifacts and unnecessary complexity
          - Run `/docs` to update documentation (CLAUDE.md and native auto-memory)
        '';

        # Settings for ~/.claude/settings.json
        settings =
          lib.warnIf (lib.versionOlder lastVerifiedVersion claudeVersion)
            "claude-code ${claudeVersion} is newer than the model-verified ${lastVerifiedVersion}: re-check the ANTHROPIC_DEFAULT_*_MODEL pins and bump lastVerifiedVersion in modules/programs/claude/default.nix"
            {
              env = {
                # Workaround for anthropics/claude-code#11205 — silent rg failure hides ~/.claude/agents.
                CLAUDE_CODE_USE_NATIVE_FILE_SEARCH = "1";

                # Pin what the aliases resolve to (keeps `opus` on the 4.x line, not Opus 5).
                ANTHROPIC_DEFAULT_OPUS_MODEL = "claude-opus-4-8[1m]";
                ANTHROPIC_DEFAULT_SONNET_MODEL = "claude-sonnet-4-5";
                ANTHROPIC_DEFAULT_HAIKU_MODEL = "claude-haiku-4-5";
              };
            };
      };

      # Preserve Claude Code's claude-cli:// deep-link handler declaratively. The
      # zathura module enables xdg.mimeApps, which makes ~/.config/mimeapps.list a
      # read-only store symlink — so Claude Code can no longer self-register this
      # handler at runtime. Declaring it here keeps deep-links working. Claude Code
      # still writes the .desktop file itself into ~/.local/share/applications.
      xdg.mimeApps.defaultApplications."x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
}
