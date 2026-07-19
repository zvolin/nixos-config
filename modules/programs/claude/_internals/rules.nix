{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Languages the user works in. Tune this list to add/drop guides.
  ruleLanguages = [
    "rust"
    "go"
    "python"
    "typescript"
    "javascript"
  ];

  # Only base/core.md + the selected language guides. Excludes the framework
  # guides, both READMEs, and base/git.md (git conventions live in the global
  # context, and git.md's "commit directly to main" contradicts the user's
  # never-edit-on-main rule).
  curatedRules = pkgs.runCommand "claude-rules-curated" { } ''
    mkdir -p "$out/base" "$out/languages"
    cp ${inputs.claude-rules}/base/core.md "$out/base/core.md"
    ${lib.concatMapStringsSep "\n" (
      lang: ''cp ${inputs.claude-rules}/languages/${lang}.md "$out/languages/${lang}.md"''
    ) ruleLanguages}
  '';
in
{
  programs.claude-code.rulesDir = "${curatedRules}";
}
