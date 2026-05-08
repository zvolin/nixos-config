{ inputs, ... }:
{
  home.file.".config/claude/rules".source = "${inputs.claude-rules}";
}
