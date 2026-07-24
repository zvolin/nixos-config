{ ... }:
let
  aiSharedContext = import ../_ai-context.nix;
in
{
  flake.modules.homeManager.codex =
    { pkgs, lib, ... }:
    let
      guard = import ../_command-guard { inherit pkgs lib; };
    in
    {
      imports = [
        ./_internals/agents.nix
        ./_internals/sandbox.nix
      ];

      programs.codex = {
        enable = true;
        enableMcpIntegration = true;

        context = ''
          ${aiSharedContext}

          # Declarative Configuration

          - This is a NixOS system. To change system or user config, edit Nix files — do not create or modify dotfiles, system configs, or service files directly.
          - Home Manager is a NixOS module (not standalone). There is no `home-manager switch` command.

          # Web and Tools

          - Use the built-in `web_search` tool to find information online (enabled via `web_search = "live"`). Do not shell out to `curl` for search.
          - There is no native URL-fetch tool. To read a specific known URL, `curl` it (you get raw HTML); prefer `web_search` for find-and-read tasks.
          - mcp-nixos for NixOS / Home Manager option lookups.
          - context7 for library documentation.
          - Use `gh` (installed and authenticated) for GitHub PRs, issues, and code search — structured output via `gh --json`.
        '';

        rules.nix-managed = ''
          prefix_rule(pattern=["claude"], decision="allow")
          ${guard.forbiddenRules}
        '';

        settings = {
          model = "gpt-5.6-terra";
          model_reasoning_effort = "medium";
          approval_policy = "on-request";
          sandbox_mode = "workspace-write";
          sandbox_workspace_write.network_access = true;
          # Codex trust is per-project-root, not recursive, and the config is a
          # read-only Nix symlink — so runtime "trust this folder" writes fail.
          # Declare trusted roots here instead; add new ones as a config change.
          projects."/home/zwolin".trust_level = "trusted";
          projects."/home/zwolin/docs".trust_level = "trusted";
          projects."/persist/etc/nixos".trust_level = "trusted";

          # Native first-party web search (sandbox already has network).
          web_search = "live";

          # Nix owns the binary; skip the useless startup update call.
          check_for_update_on_startup = false;

          # No neovim opener option; the default emits dead vscode:// links in
          # kitty+nvim. Plain path:line is cleaner.
          file_opener = "none";

          tui = {
            status_line = [
              "model-name"
              "git-branch"
              "context-used"
              "context-window-size"
              # OpenAI removed the rolling 5-hour window for Plus/Pro/Business
              # (2026-07-12), so "five-hour-limit" renders blank and is dropped.
              # No reset-ETA token exists: the backend returns resetsAt but no
              # status-line element surfaces it. Adopt a native token when one
              # lands — openai/codex#18812, openai/codex#24080.
              "weekly-limit"
            ];
            status_line_use_colors = true;
            # OSC 9 cannot carry the custom header and would double-fire against
            # the attention hook (now in the NixOS arm's /etc/codex/config.toml);
            # that hook covers needs-you on both channels.
            notifications = false;
          };

        };

        profiles.deep = {
          model = "gpt-5.6-sol";
          model_reasoning_effort = "xhigh";
        };
      };
    };

  flake.modules.nixos.codex =
    { pkgs, lib, ... }:
    let
      guard = import ../_command-guard { inherit pkgs lib; };
      denyGuard = guard.mkGuardScript {
        name = "codex-check-bash-command";
        softDecision = "deny";
      };
      notify = import ../../services/_notify-push.nix { inherit pkgs; };
      notifyTitle = import ../_notify-title.nix {
        inherit pkgs lib;
        client = "codex";
      };
      # Codex delivers PreToolUse payloads on stdin (not argv). Fire a desktop +
      # remote notification only for the two attention tools; stays a pure
      # notifier (empty stdout, exit 0) so it never alters Codex control flow.
      attentionNotify = pkgs.writeShellApplication {
        name = "codex-attention-notify";
        runtimeInputs = [
          pkgs.jq
          pkgs.libnotify
          notify.package
        ];
        text = ''
          payload=$(cat)
          [ -z "$payload" ] && exit 0
          # Bail cleanly on a non-JSON payload. The hook is synchronous, so a jq
          # parse failure under `set -e` would abort non-zero mid tool call.
          printf '%s' "$payload" | jq empty 2>/dev/null || exit 0
          tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
          title=$(${notifyTitle} "$payload")
          case "$tool_name" in
            request_user_input)
              body=$(printf '%s' "$payload" | jq -r \
                '.tool_input.questions[0].question // .tool_input.questions[0].header // "Input requested"') ;;
            update_plan)
              body="Plan ready for review" ;;
            *)
              body="Codex needs your attention" ;;
          esac
          # Push FIRST: this runs under `set -euo pipefail`; a failing local
          # toast (e.g. no dbus target) must not kill the remote push.
          notify-push "$title" high warning "$body"
          notify-send "$title" "$body" || true
          exit 0
        '';
      };
    in
    {
      # Codex's managed System config layer (is_managed by virtue of living under
      # /etc/codex on Linux — the loader hardcodes this dir and ignores
      # CODEX_HOME). Managed layers skip the hook trust-hash check, so these raw
      # /nix/store commands run across rebuilds with no re-trust and no
      # --dangerously-bypass-hook-trust flag. Both Codex PreToolUse hooks live
      # here: the deny-guard (^Bash$) and the attention notifier
      # (request_user_input|update_plan). Their matchers do not overlap, so the
      # two stay independent within this layer. Every other Codex setting stays in
      # the HM-generated ~/.codex/config.toml User layer, and the two layers merge.
      #
      # The attention notifier is synchronous (no async): codex-cli 0.144.4 skips
      # async hooks entirely. It does cheap local work (a bounded ntfy curl + a
      # dbus toast) at natural pause points, so the inline latency is negligible.
      #
      # This arm deliberately does NOT wire the HM module via
      # home-manager.sharedModules: the HM codex module is already imported once,
      # per-user, in modules/users/zvolin.nix. Wiring it a second time would
      # evaluate it twice and silently duplicate list options (notify, status_line).
      environment.etc."codex/config.toml".text = ''
        [[hooks.PreToolUse]]
        matcher = "^Bash$"

        [[hooks.PreToolUse.hooks]]
        type = "command"
        command = "${denyGuard}/bin/${denyGuard.name}"

        [[hooks.PreToolUse]]
        matcher = "request_user_input|update_plan"

        [[hooks.PreToolUse.hooks]]
        type = "command"
        command = "${lib.getExe attentionNotify}"
      '';
    };
}
