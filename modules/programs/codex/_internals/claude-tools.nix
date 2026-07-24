{
  pkgs,
  lib,
  jail,
}:
let
  claude = jail.clients.claude;
  callerMarker = jail.clients.codex.markerEnv;
  unleashStr = lib.escapeShellArgs claude.unleashFlags;

  claudeShim = pkgs.writeShellScriptBin "claude" ''
    # This shim runs the RAW claude binary unleashed, with no own bwrap — the
    # outer Codex jail is the only containment. Refuse to run if we are not
    # inside it (fail-closed: unleashed <=> contained).
    if [ -z "''${${callerMarker}:-}" ]; then
      echo "claude bridge: refusing to run unleashed outside Codex's jail (${callerMarker} unset)" >&2
      exit 1
    fi
    # Seed persistent trust for the cwd + git root before launching claude, so
    # the nested claude opens the project without a folder-trust prompt.
    ${claude.trustPrelude}
    exec ${claude.rawBinary} ${unleashStr} "$@"
  '';
in
{
  inherit claudeShim;
}
