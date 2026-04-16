{ config, inputs, lib, pkgs, ... }:

let
  patches = [
    ../../patches/superpowers-brainstorming.patch
    ../../patches/superpowers-writing-plans.patch
    ../../patches/superpowers-executing-plans.patch
    ../../patches/superpowers-subagent-driven-dev.patch
    ../../patches/superpowers-code-quality-reviewer.patch
    ../../patches/superpowers-implementer-prompt.patch
  ];

  revFallback =
    if (inputs.superpowers ? shortRev) then inputs.superpowers.shortRev
    else if (inputs.superpowers ? dirtyShortRev) then inputs.superpowers.dirtyShortRev
    else "unknown";

  # Turns over when upstream source or any patch changes — the
  # plugin-cache buster embedded in `version` below.
  cacheKey = builtins.substring 0 8 (
    builtins.hashString "sha256" (
      builtins.concatStringsSep ":" (map toString ([ inputs.superpowers ] ++ patches))
    )
  );

  version = let
    pluginJson = "${inputs.superpowers}/.claude-plugin/plugin.json";
    parsed = builtins.tryEval (builtins.fromJSON (builtins.readFile pluginJson));
    baseVersion =
      if builtins.pathExists pluginJson && parsed.success
      then parsed.value.version or revFallback
      else revFallback;
  # Claude Code caches extracted plugins at cache/<marketplace>/<plugin>/<version>/,
  # so a new string forces a fresh extract.
  in "${baseVersion}+${cacheKey}";

  patchedSuperpowers = pkgs.applyPatches {
    name = "superpowers-patched-${version}";
    src = inputs.superpowers;
    inherit patches;
    nativeBuildInputs = [ pkgs.jq ];
    # Align plugin.json version with marketplace.json for cache key agreement.
    postPatch = ''
      jq --arg v "${version}" '.version = $v' \
        .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
      mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json
    '';
  };

  pluginName = "superpowers";
  marketplaceName = "nix-plugins";
  pluginId = "${pluginName}@${marketplaceName}";
  pluginsDir = "${config.home.homeDirectory}/.claude/plugins";
  marketplaceDir = "${pluginsDir}/marketplaces/${marketplaceName}";
  epoch = "1970-01-01T00:00:00.000Z";

  installedEntry = builtins.toJSON [{
    scope = "user";
    installPath = "${marketplaceDir}/${pluginName}";
    inherit version;
    installedAt = epoch;
    lastUpdated = epoch;
    gitCommitSha = inputs.superpowers.rev or "unknown";
  }];

  marketplaceEntry = builtins.toJSON {
    source = { source = "directory"; path = marketplaceDir; };
    installLocation = marketplaceDir;
    lastUpdated = epoch;
  };
in
{
  home.file = {
    ".claude/plugins/marketplaces/${marketplaceName}/${pluginName}" = {
      source = patchedSuperpowers;
    };

    ".claude/plugins/marketplaces/${marketplaceName}/.claude-plugin/marketplace.json" = {
      text = builtins.toJSON {
        "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
        name = marketplaceName;
        description = "Nix-managed plugins";
        owner = { name = "nix"; email = "nix@localhost"; };
        plugins = [{
          name = pluginName;
          description = "Complete software development workflow skills";
          source = "./${pluginName}";
          inherit version;
        }];
      };
    };
  };

  # Plugin state lives in two JSON files shared with non-Nix plugins (skill-codex,
  # rust-analyzer-lsp). We merge our entry rather than owning the files outright.
  # The marketplaces/ directory on disk (home.file above) must agree.
  home.activation.nixPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "$DRY_RUN_CMD" ]; then
      $VERBOSE_ECHO "Would merge ${marketplaceName} entries into Claude plugin state"
    else
      jq=${lib.getExe pkgs.jq}
      mkdir -p "${pluginsDir}"

      merge_json() {
        local file=$1
        local filter=$2
        local entry=$3
        local tmp="$file.tmp"
        # Remove stale symlinks (e.g. from old HM generations) before merging
        [ -L "$file" ] && rm -f "$file"
        if [ -f "$file" ] && "$jq" --argjson entry "$entry" "$filter" "$file" > "$tmp" 2>/dev/null; then
          mv "$tmp" "$file"
        else
          rm -f "$tmp"
          printf 'null\n' | "$jq" --argjson entry "$entry" "$filter" > "$tmp" && mv "$tmp" "$file"
        fi
      }

      merge_json "${pluginsDir}/installed_plugins.json" \
        '.version = 2 | .plugins["${pluginId}"] = $entry' \
        ${lib.escapeShellArg installedEntry}

      merge_json "${pluginsDir}/known_marketplaces.json" \
        '.["${marketplaceName}"] = $entry' \
        ${lib.escapeShellArg marketplaceEntry}
    fi
  '';

  programs.claude-code.settings = {
    enabledPlugins = {
      "${pluginId}" = true;
    };
  };
}
