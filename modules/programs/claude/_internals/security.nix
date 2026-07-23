{
  pkgs,
  lib,
  ...
}:
let
  guard = import ../../_command-guard { inherit pkgs lib; };

  check-bash-command = guard.mkGuardScript {
    name = "claude-check-bash-command";
    softDecision = "ask";
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
            command = "${check-bash-command}/bin/${check-bash-command.name}";
          }
        ];
      }
    ];
  };
}
