{
  pkgs,
  lib,
  ...
}:
let
  # --- Bash validation hook ---
  blockedCommands = [
    "sudo"
    "doas"
    "eval"
    "dd"
    "mkfs"
    "shred"
  ];
  deniedSubcommands = [
    "git push"
    "git push --force"
    "git push -f"
  ];
  blockedPatterns = [
    "curl|sh"
    "curl|bash"
    "wget|sh"
    "wget|bash"
    "curl|python"
    "wget|python"
  ];

  blockedCommandsStr = builtins.concatStringsSep " " blockedCommands;
  deniedSubcommandsStr = builtins.concatStringsSep "\n" deniedSubcommands;

  # Convert "source|sink" shorthand to "source.*\|.*sink" grep regex
  patternToRegex =
    pattern:
    let
      parts = builtins.split "\\|" pattern;
      source = builtins.elemAt parts 0;
      sink = builtins.elemAt parts 2;
    in
    "${source}.*\\|.*${sink}";

  blockedPatternsStr = builtins.concatStringsSep "\n" (map patternToRegex blockedPatterns);

  checkBashCommandSrc =
    builtins.replaceStrings
      [ "@blockedCommands@" "@deniedSubcommands@" "@blockedPatterns@" ]
      [ blockedCommandsStr deniedSubcommandsStr blockedPatternsStr ]
      (builtins.readFile ./check-bash-command.sh);

  check-bash-command =
    let
      script = pkgs.writeShellScriptBin "claude-check-bash-command" checkBashCommandSrc;
    in
    pkgs.symlinkJoin {
      name = "claude-check-bash-command";
      paths = [ script ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/claude-check-bash-command \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.shfmt
              pkgs.jq
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gawk
            ]
          }
      '';
    };
in
{
  programs.claude-code.settings = {
    skipDangerousModePermissionPrompt = true;
    # Safe fail-closed floor for unwrapped launches / jail-setup failure. The
    # wrapper injects --dangerously-skip-permissions for autonomy; this static
    # value must stay maximally conservative so a raw-binary launch is prompted.
    permissions.defaultMode = "default";

    hooks.PreToolUse = [
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
    ];
  };
}
