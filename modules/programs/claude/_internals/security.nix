{
  pkgs,
  lib,
  ...
}: let
  # --- MCP tool name helpers (must match permissions.nix) ---
  mcpPrefix = "mcp__plugin_claude-code-home-manager";
  ferrex = tool: "${mcpPrefix}_ferrex__${tool}";
  serena = tool: "${mcpPrefix}_serena__${tool}";
  # --- Bash validation hook ---
  blockedCommands = ["sudo" "doas" "eval" "dd" "mkfs" "shred"];
  deniedSubcommands = ["git push" "git push --force" "git push -f"];
  blockedSubcommands = []; # configurable, empty by default
  blockedPatterns = ["curl|sh" "curl|bash" "wget|sh" "wget|bash" "curl|python" "wget|python"];

  blockedCommandsStr = builtins.concatStringsSep " " blockedCommands;
  deniedSubcommandsStr = builtins.concatStringsSep "\n" deniedSubcommands;
  blockedSubcommandsStr = builtins.concatStringsSep "\n" blockedSubcommands;

  # Convert "source|sink" shorthand to "source.*\|.*sink" grep regex
  patternToRegex = pattern: let
    parts = builtins.split "\\|" pattern;
    source = builtins.elemAt parts 0;
    sink = builtins.elemAt parts 2;
  in "${source}.*\\|.*${sink}";

  blockedPatternsStr = builtins.concatStringsSep "\n" (map patternToRegex blockedPatterns);

  checkBashCommandSrc =
    builtins.replaceStrings
    ["@blockedCommands@" "@blockedSubcommands@" "@deniedSubcommands@" "@blockedPatterns@"]
    [blockedCommandsStr blockedSubcommandsStr deniedSubcommandsStr blockedPatternsStr]
    (builtins.readFile ./check-bash-command.sh);

  check-bash-command = let
    script = pkgs.writeShellScriptBin "claude-check-bash-command" checkBashCommandSrc;
  in
    pkgs.symlinkJoin {
      name = "claude-check-bash-command";
      paths = [script];
      buildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/claude-check-bash-command \
          --prefix PATH : ${lib.makeBinPath [pkgs.shfmt pkgs.jq pkgs.coreutils pkgs.gnugrep pkgs.gawk]}
      '';
    };

  # --- Confirm hooks ---

  confirmEntries = [
    {
      tool = ferrex "store";
      reason = "Storing to ferrex memory. This persists across sessions.";
    }
    {
      tool = ferrex "forget";
      reason = "Deleting ferrex memory. This is permanent.";
    }
    {
      tool = serena "write_memory";
      reason = "Writing to Serena memory.";
    }
    {
      tool = serena "edit_memory";
      reason = "Editing Serena memory.";
    }
    {
      tool = serena "delete_memory";
      reason = "Deleting Serena memory.";
    }
  ];

  mkConfirmHook = entry: {
    matcher = entry.tool;
    hooks = [
      {
        type = "command";
        command = ''echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"${entry.reason}"}}'  '';
      }
    ];
  };
in {
  programs.claude-code.settings = {
    skipDangerousModePermissionPrompt = true;
    permissions.defaultMode = "bypassPermissions";

    hooks.PreToolUse =
      [
        # Bash command validation (shfmt AST)
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "${check-bash-command}/bin/claude-check-bash-command";
            }
          ];
        }
      ]
      # Confirm hooks for memory-mutating MCP tools
      ++ (map mkConfirmHook confirmEntries);
  };
}
