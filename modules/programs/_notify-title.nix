# Shared AI-client notification title builder. Underscore-prefixed so
# import-tree skips auto-discovery (this is a plain builder, not a flake
# module); both the Claude hooks module and the Codex module `import` it
# directly, mirroring the shared `modules/services/_notify-push.nix`. Neither
# client reaches into the other's internals.
#
# Parameterized by client name; the returned script takes the hook payload
# JSON as $1 (the caller has already consumed stdin) and prints the title with
# no trailing newline. Primary source is the `ai-launch` session env
# (AI_SESSION_PROJECT / AI_SESSION_TAB); falls back to the payload cwd basename.
# The out path IS the executable script.
{
  pkgs,
  lib,
  client,
}:
pkgs.writeShellScript "notify-title-${client}" ''
  input=''${1:-}
  if [ -n "''${AI_SESSION_PROJECT:-}" ]; then
    if [ -n "''${AI_SESSION_TAB:-}" ]; then
      printf '%s #%s ${client}' "$AI_SESSION_PROJECT" "$AI_SESSION_TAB"
    else
      printf '%s ${client}' "$AI_SESSION_PROJECT"
    fi
  else
    cwd=$(printf '%s' "$input" | ${lib.getExe pkgs.jq} -r '.cwd // empty')
    if [ -n "$cwd" ]; then
      printf '%s ${client}' "$(basename "$cwd")"
    else
      printf '${client}'
    fi
  fi
''
