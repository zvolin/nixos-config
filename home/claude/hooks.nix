{ ... }:

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
              notify-send "$title" "$message"
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
