{ inputs, ... }:
{
  # Every module here is headless-clean (zero GUI dependency). Shared by
  # `zwolin-desktop` and the `nas` host (rpi/configuration.nix explains why rpi
  # stays minimal). `gh` rides with the set because the agents, the `/pr` skill,
  # and the jail's `~/.config/gh` whitelist all require it. It otherwise travels
  # only on the desktop profile.
  flake.modules.homeManager.ai-headless =
    { pkgs, ... }:
    {
      imports = with inputs.self.modules.homeManager; [
        claude
        codex
        mcp
        superpowers
        skill-codex
        cleanup
        dissent-review
        humanizer
        research
        review
        post-implementation-polish
        mattpocock-architecture
        mattpocock-domain-modeling
        mattpocock-handoff
        mattpocock-wayfinder
        threat-modeling-expert
      ];

      # The zellij editor/agent layer travels with the AI set.
      zellijLlm.enable = true;

      home.packages = [ pkgs.gh ];
    };
}
