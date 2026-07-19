{ ... }:
let
  aiSharedContext = import ../_ai-context.nix;
in
{
  flake.modules.homeManager.codex =
    { pkgs, lib, ... }:
    let
      # Codex appends a JSON event payload as the final arg. On
      # agent-turn-complete, toast the assistant's last message via notify-send
      # (notify-send + dbus are already wired into the environment).
      notifyWrapper = pkgs.writeShellApplication {
        name = "codex-notify";
        runtimeInputs = [
          pkgs.jq
          pkgs.libnotify
        ];
        text = ''
          payload=''${1:-}
          [ -z "$payload" ] && exit 0
          msg=$(printf '%s' "$payload" | jq -r 'if .type == "agent-turn-complete" then (."last-assistant-message" // "Turn complete") else empty end')
          [ -z "$msg" ] && exit 0
          notify-send "Codex" "$msg"
        '';
      };
    in
    {
      imports = [ ./_internals/agents.nix ];

      programs.codex = {
        enable = true;
        enableMcpIntegration = true;

        context = ''
          ${aiSharedContext}

          # Declarative Configuration

          - This is a NixOS system. To change system or user config, edit Nix files — do not create or modify dotfiles, system configs, or service files directly.
          - Home Manager is a NixOS module (not standalone). There is no `home-manager switch` command.

          # Running Claude Code

          - To run Claude Code (the `claude` CLI), request escalated / unsandboxed execution.
          - Claude applies its own bubblewrap isolation. Nesting it inside Codex's workspace-write sandbox breaks it: writes to `~/.claude` and other state dirs are denied, and the model API network is blocked.
          - Running `claude` escalated lets it reapply its own jail, so the net boundary is Claude's wrapper, not "no sandbox".

          # Web and Tools

          - Use the built-in `web_search` tool to find information online (enabled via `web_search = "live"`). Do not shell out to `curl` for search.
          - There is no native URL-fetch tool. To read a specific known URL, `curl` it (you get raw HTML); prefer `web_search` for find-and-read tasks.
          - mcp-nixos for NixOS / Home Manager option lookups.
          - context7 for library documentation.
          - Use `gh` (installed and authenticated) for GitHub PRs, issues, and code search — structured output via `gh --json`.
        '';

        rules.nix-managed = ''
          prefix_rule(pattern=["claude"], decision="allow")
        '';

        settings = {
          model = "gpt-5.6-terra";
          model_reasoning_effort = "medium";
          approval_policy = "on-request";
          sandbox_mode = "workspace-write";
          sandbox_workspace_write.network_access = true;
          projects."/home/zwolin".trust_level = "trusted";
          projects."/persist/etc/nixos".trust_level = "trusted";

          # Native first-party web search (sandbox already has network).
          web_search = "live";

          # Nix owns the binary; skip the useless startup update call.
          check_for_update_on_startup = false;

          # No neovim opener option; the default emits dead vscode:// links in
          # kitty+nvim. Plain path:line is cleaner.
          file_opener = "none";

          notify = [ (lib.getExe notifyWrapper) ];

          tui = {
            status_line = [
              "model-name"
              "git-branch"
              "context-used"
              "context-window-size"
              "five-hour-limit"
              "weekly-limit"
            ];
            status_line_use_colors = true;
            # In-terminal toast on turn-done AND approval-needed (kitty
            # forwards OSC 9 → dbus). Pairs with `notify` (different events).
            notifications = true;
          };
        };

        profiles.deep = {
          model = "gpt-5.6-sol";
          model_reasoning_effort = "xhigh";
        };

        # One-flag unattended mode (`codex --profile auto`); the
        # workspace-write sandbox stays as the guardrail. The interactive
        # default remains `on-request`.
        profiles.auto = {
          approval_policy = "never";
        };
      };
    };
}
