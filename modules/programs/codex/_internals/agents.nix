{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.codex;
  tomlFormat = pkgs.formats.toml { };

  # Claude frontmatter `model:` → Codex model tier. `sonnet` means "as cheap
  # as safe": Codex has no mid tier, so it rounds `sonnet` up to the top tier.
  # That is a faithful rendering of "not cheap", not a leak — `terra` is the
  # deliberately-declined weak-implementer risk. opus also lands on the top
  # tier; haiku maps to the lighter `terra` tier. Trigger: when a mid Codex
  # tier ships, add one line here and every `sonnet` agent cheapens
  # automatically.
  modelMap = {
    opus = "gpt-5.6";
    sonnet = "gpt-5.6";
    haiku = "gpt-5.6-terra";
  };

  # Mirrors what Codex's `model_reasoning_effort` field actually accepts.
  # Resolution and clamp rules are documented on `programs.codex.agents` below.
  codexEfforts = [
    "low"
    "medium"
    "high"
  ];

  # Agents load from `config_folder.join("agents")` in
  # codex-rs/core/src/config/agent_roles.rs (verified against codex 0.122.0),
  # where `config_folder` is `~/.codex/`. The 0.94+ split moved skills to
  # `~/.agents/skills/`, but agents stayed under `~/.codex/agents/`.
  agentsDir = ".codex/agents";

  # Split a Claude-format agent .md into { frontmatter-attrs; prompt-body }.
  # The frontmatter is a fixed set of `key: value` lines between the first
  # two --- markers. No nested YAML. Sources without a leading `---\n` are
  # rejected up front; without that guard `lib.removePrefix` would silently
  # treat the entire body as frontmatter and the error would surface later
  # as a confusing "missing description" throw.
  parseAgent =
    source:
    let
      src = if lib.isPath source || lib.isStorePath source then builtins.readFile source else source;
      _ =
        lib.throwIfNot (lib.hasPrefix "---\n" src)
          "programs.codex.agents: source does not start with `---\\n` frontmatter delimiter"
          null;
      afterOpen = lib.removePrefix "---\n" src;
      splits = lib.splitString "\n---\n" afterOpen;
      frontmatter = builtins.head splits;
      body = lib.removePrefix "\n" (lib.concatStringsSep "\n---\n" (builtins.tail splits));
      fmLines = lib.splitString "\n" frontmatter;
      parseLine =
        line:
        let
          m = builtins.match "([a-zA-Z_-]+): (.*)" line;
        in
        if m == null then null else lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1);
      fm = builtins.listToAttrs (builtins.filter (x: x != null) (builtins.map parseLine fmLines));
    in
    builtins.seq _ { inherit fm body; };

  mkAgentToml =
    name: source:
    let
      parsed = parseAgent source;
      claudeModel = parsed.fm.model or "sonnet";
      codexModel = modelMap.${claudeModel} or "gpt-5.6";
      # Effort resolution and clamp rules: see the `programs.codex.agents`
      # option description below.
      rawEffort = parsed.fm.reasoning_effort or parsed.fm.effort or "medium";
      reasoningEffort = if lib.elem rawEffort codexEfforts then rawEffort else "high";
    in
    tomlFormat.generate "codex-agent-${name}.toml" (
      {
        inherit name;
        description =
          parsed.fm.description
            or (throw "programs.codex.agents.${name}: frontmatter is missing required `description` key");
        # `developer_instructions` is the field name in ConfigToml
        # (codex-rs/config/src/config_toml.rs); it is validated as required for
        # discovered agent files by validate_agent_role_file_developer_instructions.
        developer_instructions = parsed.body;
        model_reasoning_effort = reasoningEffort;
      }
      // lib.optionalAttrs (parsed.fm ? model) { model = codexModel; }
    );
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
