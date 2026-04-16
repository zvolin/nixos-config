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
    # Rewrite plugin.json's version so the served tree agrees with
    # marketplace.json on the cache key.
    postPatch = ''
      jq --arg v "${version}" '.version = $v' \
        .claude-plugin/plugin.json > .claude-plugin/plugin.json.tmp
      mv .claude-plugin/plugin.json.tmp .claude-plugin/plugin.json
    '';
  };

  commitSha = inputs.superpowers.rev or "unknown";

  homeDir = config.home.homeDirectory;
  pluginsDir = "${homeDir}/.claude/plugins";
  marketplaceName = "nix-plugins";
  pluginInstallDir = "${pluginsDir}/marketplaces/${marketplaceName}/superpowers";

  # JSON for jq --argjson (array of plugin entries for merging into installed_plugins.json)
  installedPluginJson = builtins.toJSON [{
    scope = "user";
    installPath = pluginInstallDir;
    inherit version;
    installedAt = "1970-01-01T00:00:00.000Z";
    lastUpdated = "1970-01-01T00:00:00.000Z";
    gitCommitSha = commitSha;
  }];

  # Full installed_plugins.json for fresh-create / fallback
  installedPluginsFull = builtins.toJSON {
    version = 2;
    plugins = {
      "superpowers@${marketplaceName}" = [{
        scope = "user";
        installPath = pluginInstallDir;
        inherit version;
        installedAt = "1970-01-01T00:00:00.000Z";
        lastUpdated = "1970-01-01T00:00:00.000Z";
        gitCommitSha = commitSha;
      }];
    };
  };

  # JSON for jq --argjson (known marketplace entry)
  knownMarketplaceJson = builtins.toJSON {
    source = {
      source = "directory";
      path = "${pluginsDir}/marketplaces/${marketplaceName}";
    };
    installLocation = "${pluginsDir}/marketplaces/${marketplaceName}";
    lastUpdated = "1970-01-01T00:00:00.000Z";
  };

  # Full known_marketplaces.json for fresh-create / fallback
  knownMarketplacesFull = builtins.toJSON {
    "${marketplaceName}" = {
      source = {
        source = "directory";
        path = "${pluginsDir}/marketplaces/${marketplaceName}";
      };
      installLocation = "${pluginsDir}/marketplaces/${marketplaceName}";
      lastUpdated = "1970-01-01T00:00:00.000Z";
    };
  };
in
{
  home.file = {
    ".claude/plugins/marketplaces/${marketplaceName}/superpowers" = {
      source = patchedSuperpowers;
    };

    # Marketplace descriptor
    ".claude/plugins/marketplaces/${marketplaceName}/.claude-plugin/marketplace.json" = {
      text = builtins.toJSON {
        "$schema" = "https://anthropic.com/claude-code/marketplace.schema.json";
        name = marketplaceName;
        description = "Nix-managed plugins";
        owner = {
          name = "nix";
          email = "nix@localhost";
        };
        plugins = [{
          name = "superpowers";
          description = "Complete software development workflow skills";
          source = "./superpowers";
          inherit version;
        }];
      };
    };
  };

  # The marketplace is registered in three places that must agree:
  # 1. programs.claude-code.settings.extraKnownMarketplaces — so Claude Code's settings know about it
  # 2. known_marketplaces.json via activation script — so the plugin system finds it at runtime
  # 3. marketplaces/ directory on disk — so the actual plugin files are accessible
  # We use activation scripts for (2) because we share these JSON files with
  # non-Nix-managed plugins (skill-codex, rust-analyzer-lsp).
  home.activation.nixPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Skip plugin registration during dry run — redirections can't be guarded by $DRY_RUN_CMD
    if [ -n "$DRY_RUN_CMD" ]; then
      $VERBOSE_ECHO "Would merge nix-plugins entries into installed_plugins.json and known_marketplaces.json"
    else
      mkdir -p "${pluginsDir}"

      # Merge into installed_plugins.json
      plugins_file="${pluginsDir}/installed_plugins.json"
      if [ -f "$plugins_file" ] && [ ! -L "$plugins_file" ]; then
        # Remove old superpowers-marketplace entry if present, add nix-plugins entry
        if ! ${lib.getExe pkgs.jq} --argjson entry ${lib.escapeShellArg installedPluginJson} '
          .plugins |= (del(.["superpowers@superpowers-marketplace"]) | .["superpowers@${marketplaceName}"] = $entry)
        ' "$plugins_file" > "$plugins_file.tmp"; then
          # jq failed (corrupt file?) — recreate with just our entry
          printf '%s\n' ${lib.escapeShellArg installedPluginsFull} > "$plugins_file"
          rm -f "$plugins_file.tmp"
        else
          mv "$plugins_file.tmp" "$plugins_file"
        fi
      else
        # Remove stale symlink (e.g. from old HM generation) before writing
        rm -f "$plugins_file"
        printf '%s\n' ${lib.escapeShellArg installedPluginsFull} > "$plugins_file"
      fi

      # Merge into known_marketplaces.json
      known_file="${pluginsDir}/known_marketplaces.json"
      if [ -f "$known_file" ] && [ ! -L "$known_file" ]; then
        if ! ${lib.getExe pkgs.jq} --argjson entry ${lib.escapeShellArg knownMarketplaceJson} '
          del(.["superpowers-marketplace"]) | .["${marketplaceName}"] = $entry
        ' "$known_file" > "$known_file.tmp"; then
          printf '%s\n' ${lib.escapeShellArg knownMarketplacesFull} > "$known_file"
          rm -f "$known_file.tmp"
        else
          mv "$known_file.tmp" "$known_file"
        fi
      else
        # Remove stale symlink (e.g. from old HM generation) before writing
        rm -f "$known_file"
        printf '%s\n' ${lib.escapeShellArg knownMarketplacesFull} > "$known_file"
      fi
    fi
  '';

  programs.claude-code.settings = {
    enabledPlugins = {
      "superpowers@${marketplaceName}" = true;
    };

    extraKnownMarketplaces = {
      ${marketplaceName} = {
        source = {
          source = "directory";
          path = "${pluginsDir}/marketplaces/${marketplaceName}";
        };
        installLocation = "${pluginsDir}/marketplaces/${marketplaceName}";
      };
    };
  };
}
