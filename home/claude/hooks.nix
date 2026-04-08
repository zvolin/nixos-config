{ ... }:

{
  programs.claude-code.settings.hooks = {
    Notification = [
      {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "notify-send 'Claude Code' 'Needs your attention'";
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
