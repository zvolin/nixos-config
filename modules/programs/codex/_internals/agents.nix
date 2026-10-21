{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codex;

  # The same JSON->TOML converter that `pkgs.formats.toml` uses internally, so
  # the build-time transform below emits byte-identical TOML to the former
  # eval-time `tomlFormat.generate` path. Referenced through `pkgs.path` rather
  # than vendored, so it tracks the nixpkgs the rest of the config pins.
  json2x = pkgs.buildPackages.callPackage "${pkgs.path}/pkgs/pkgs-lib/formats/json2x/package.nix" { };

  # Agents load from `config_folder.join("agents")` in
  # codex-rs/core/src/config/agent_roles.rs (verified against codex 0.122.0),
  # where `config_folder` is `~/.codex/`. The 0.94+ split moved skills to
  # `~/.agents/skills/`, but agents stayed under `~/.codex/agents/`.
  agentsDir = ".codex/agents";

  # Transform a Claude-format agent .md into a Codex agent TOML at build time,
  # so no source is read during evaluation. See ../../ai-skills/_ifd-safe-skill.nix.
  mkAgentToml =
    name: source:
    let
      srcFile =
        if lib.isPath source || lib.isStorePath source then
          source
        else
          pkgs.writeText "codex-agent-${name}.md" source;
    in
    pkgs.runCommand "codex-agent-${name}.toml"
      {
        nativeBuildInputs = [
          pkgs.python3
          json2x
        ];
        preferLocalBuild = true;
      }
      ''
        python3 ${./parse-agent.py} ${srcFile} ${lib.escapeShellArg name} > value.json
        json2x toml value.json "$out"
      '';
in
{
  # `programs.codex` here is a local wrapper around the upstream nixpkgs module,
  # which does not currently define an `agents` option. If upstream adds one,
  # this declaration will collide — pin or drop the local option at that point.
  options.programs.codex.agents = lib.mkOption {
    type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
    default = { };
    description = ''
      Custom subagents for Codex. The attribute name is the agent identifier
      and becomes the TOML `name` field (any `name:` in the frontmatter is
      ignored on this side — Claude Code's own loader uses it). The value is
      either Claude-format markdown (YAML frontmatter with `description`,
      optional `model`, optional `reasoning_effort`, optional `effort`; then
      the prompt body) or a path to such a file.

      Codex reasoning effort resolves as `reasoning_effort` (explicit
      per-client override), else Claude's native `effort:` key, else the
      `"medium"` default. Claude-only effort values (`xhigh`, `max`) are
      clamped down to `high`, since Codex accepts only low/medium/high.

      The frontmatter is parsed at build time and re-emitted as Codex TOML
      at `~/.codex/agents/<name>.toml`, so the same source file feeds both
      Claude Code (as an agent .md) and Codex (as a generated .toml).
    '';
  };

  config.home.file = lib.mapAttrs' (
    name: source:
    lib.nameValuePair "${agentsDir}/${name}.toml" {
      source = mkAgentToml name source;
    }
  ) cfg.agents;
}
