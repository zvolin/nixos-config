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
  claude-title = import ./_notify-title.nix { inherit pkgs lib; };
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
              title=$(${claude-title} "$input")
              message=$(printf '%s' "$input" | jq -r '.message // "Needs your attention"')
              ${notify-push} "$title" high warning "$message"
              notify-send -i ${claude-icon} "$title" "$message" || true
            '';
          }
        ];
      }
    ];

    # Turn-complete: default-priority push first, then a toast for parity with
    # the Notification hook and Codex's turn-complete behavior.
    Stop = [
      {
        hooks = [
          {
            type = "command";
            command = ''
              input=$(cat)
              title=$(${claude-title} "$input")
              ${notify-push} "$title" default white_check_mark "Turn complete"
              notify-send -i ${claude-icon} "$title" "Turn complete" || true
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
