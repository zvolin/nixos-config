{ inputs, ... }:
let
  base = "${inputs.wshobson-agents}/plugins/security-scanning";
  skillNames = [
    "stride-analysis-patterns"
    "attack-tree-construction"
    "security-requirement-extraction"
    "threat-mitigation-mapping"
  ];
  skillEntry = name: {
    inherit name;
    value = "${base}/skills/${name}";
  };
  skills = builtins.listToAttrs (map skillEntry skillNames);
in
{
  flake.modules.homeManager.threat-modeling-expert =
    { pkgs, ... }:
    let
      # Codex consumes skills, not subagents. Wrap the agent .md as SKILL.md
      # so Codex can load the same methodology body as a skill. Copy (not
      # symlink) because Codex 0.94+ doesn't follow symlinked SKILL.md.
      agentAsCodexSkill = pkgs.runCommand "threat-modeling-expert-codex-skill" { } ''
        mkdir -p $out
        cp ${base}/agents/threat-modeling-expert.md $out/SKILL.md
      '';
    in
    {
      programs.claude-code.agents.threat-modeling-expert = builtins.readFile "${base}/agents/threat-modeling-expert.md";

      programs.claude-code.skills = skills;
      programs.codex.skills = skills // {
        threat-modeling-expert = "${agentAsCodexSkill}";
      };
    };
}
