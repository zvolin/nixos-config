{ pkgs, ... }:

let
  claude-icon-ico = pkgs.fetchurl {
    url = "https://claude.ai/favicon.ico";
    sha256 = "1qw5w3c2v6clyv608kizpppyz501v29cnmlmibz51szgif15asl1";
  };
  claude-icon = pkgs.runCommand "claude-icon.png" { } ''
    ${pkgs.imagemagick}/bin/convert "${claude-icon-ico}[0]" -resize 128x128 $out
  '';
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
              message=$(echo "$input" | jq -r '.message // "Needs your attention"')
              if [ -n "$CLAUDE_SESSION_NAME" ]; then
                title="Claude Code - $CLAUDE_SESSION_NAME"
              else
                cwd=$(echo "$input" | jq -r '.cwd // empty')
                if [ -n "$cwd" ]; then
                  title="Claude Code - term:$(basename "$cwd")"
                else
                  title="Claude Code"
                fi
              fi
              notify-send -i ${claude-icon} "$title" "$message"
            '';
          }
        ];
      }
    ];

    # Show bash commands together with their output each time bash command is ran
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
  };
}
