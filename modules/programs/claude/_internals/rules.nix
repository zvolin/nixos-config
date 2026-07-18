{ inputs, ... }:
{
  programs.claude-code.rulesDir = "${inputs.claude-rules}";
}
