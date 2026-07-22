# Build the Claude Code notification title from CLAUDE_SESSION_NAME or the
# cwd. Underscore-prefixed so import-tree skips auto-discovery (this is a
# plain builder, not a flake module); hooks.nix imports it directly. Takes
# the hook input JSON as $1 (the caller has already consumed stdin once).
# The out path IS the executable script.
{ pkgs, lib }:
pkgs.writeShellScript "claude-notify-title" ''
  input=''${1:-}
  if [ -n "$CLAUDE_SESSION_NAME" ]; then
    printf 'Claude Code - %s' "$CLAUDE_SESSION_NAME"
  else
    cwd=$(printf '%s' "$input" | ${lib.getExe pkgs.jq} -r '.cwd // empty')
    if [ -n "$cwd" ]; then
      printf 'Claude Code - term:%s' "$(basename "$cwd")"
    else
      printf 'Claude Code'
    fi
  fi
''
