{
  pkgs,
  lib,
  ...
}:
let
  claude-icon-ico = pkgs.fetchurl {
    url = "https://claude.ai/favicon.ico";
    sha256 = "1qw5w3c2v6clyv608kizpppyz501v29cnmlmibz51szgif15asl1";
  };
  claude-icon = pkgs.runCommand "claude-icon.png" { } ''
    ${pkgs.imagemagick}/bin/convert "${claude-icon-ico}[0]" -resize 128x128 $out
  '';
  claude-formatter = pkgs.writeShellScriptBin "claude-formatter" ''
    file_path="$1"
    [ -z "$file_path" ] || [ ! -f "$file_path" ] && exit 0

    format() {
      local cmd="$1"; shift
      local fallback="$1"; shift
      if command -v "$cmd" >/dev/null 2>&1; then
        "$cmd" "$@"
      else
        "$fallback" "$@"
      fi
    }

    case "$file_path" in
      *.nix) format nixfmt ${lib.getExe pkgs.nixfmt} -q "$file_path" ;;
      *.go)  format gofmt ${pkgs.go}/bin/gofmt -w "$file_path" ;;
      *.rs)  format rustfmt ${lib.getExe pkgs.rustfmt} "$file_path" ;;
    esac 2>/dev/null || true
  '';
  notify = import ../../../services/_notify-push.nix { inherit pkgs; };
  notify-push = lib.getExe notify.package;
  claude-title = import ../../_notify-title.nix {
    inherit pkgs lib;
    client = "claude";
  };
  # One marker file per active subagent (keyed by agent_id) lives here; the
  # Notification hook suppresses a spurious idle_prompt while any marker exists.
  # A per-agent marker (not a boolean) survives overlapping background subagents.
  subagentDir = "\${XDG_RUNTIME_DIR:-/tmp}/claude-subagents";
in
{
  programs.claude-code.settings.hooks = {
    Notification = [
      {
        matcher = "permission_prompt|idle_prompt|elicitation_dialog";
        hooks = [
          {
            type = "command";
            command = ''
              input=$(cat)
              notification_type=$(printf '%s' "$input" | jq -r '.notification_type // empty')
              # Suppress the spurious idle_prompt Claude fires while it sits idle
              # waiting on a background subagent (see spec Case A/B). Only
              # idle_prompt is gated; permission_prompt/elicitation_dialog are
              # genuine needs-human moments and always fire.
              # Correctness depends on SubagentStart arriving before idle_prompt
              # (verified live, not doc-guaranteed).
              if [ "$notification_type" = "idle_prompt" ] \
                 && [ -n "$(ls -A "${subagentDir}" 2>/dev/null)" ]; then
                exit 0
              fi
              title=$(${claude-title} "$input")
              message=$(printf '%s' "$input" | jq -r '.message // empty')
              if [ -z "$message" ]; then
                case "$notification_type" in
                  permission_prompt)   message="Permission needed" ;;
                  idle_prompt)         message="Waiting for your input" ;;
                  elicitation_dialog)  message="Input requested" ;;
                  *)                   message="Needs your attention" ;;
                esac
              fi
              ${notify-push} "$title" high warning "$message"
              notify-send -i ${claude-icon} "$title" "$message" || true
            '';
          }
        ];
      }
    ];

    SubagentStart = [
      {
        hooks = [
          {
            type = "command";
            command = ''
              input=$(cat)
              agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty')
              [ -n "$agent_id" ] || exit 0
              mkdir -p "${subagentDir}"
              : > "${subagentDir}/$agent_id"
              exit 0
            '';
          }
        ];
      }
    ];

    SubagentStop = [
      {
        hooks = [
          {
            type = "command";
            command = ''
              input=$(cat)
              agent_id=$(printf '%s' "$input" | jq -r '.agent_id // empty')
              [ -n "$agent_id" ] || exit 0
              rm -f "${subagentDir}/$agent_id"
              exit 0
            '';
          }
        ];
      }
    ];

    # A subagent that hard-crashes between SubagentStart and SubagentStop
    # leaves its marker behind, which would otherwise suppress every
    # idle_prompt for the rest of the session. Sweep it at startup/resume.
    #
    # Matcher is deliberately startup|resume only, not clear/compact: those
    # can fire while a background subagent is still running, and wiping its
    # marker mid-flight would un-suppress the idle_prompt this guard exists
    # to remove. A leaked marker just self-heals at the next startup/resume.
    SessionStart = [
      {
        matcher = "startup|resume";
        hooks = [
          {
            type = "command";
            command = ''
              rm -rf "${subagentDir}"
              exit 0
            '';
          }
        ];
      }
    ];

    # Auto-format files after every edit
    PostToolUse = [
      {
        matcher = "Edit|Write";
        hooks = [
          {
            type = "command";
            command = ''
              input=$(cat)
              file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
              [ -n "$file_path" ] && [ -f "$file_path" ] && ${lib.getExe claude-formatter} "$file_path"
              exit 0
            '';
          }
        ];
      }
    ];
  };
}
