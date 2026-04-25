# PreToolUse hook for Bash commands.
# NOTE: no shebang needed — writeShellScriptBin prepends its own nix-store bash.
# Uses shfmt to parse command AST and extract actual executables,
# then checks against blocklists. Catches dangerous commands hidden
# inside pipes, subshells, or command substitution.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

block() {
  jq -n --arg reason "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason } }'
  exit 0
}

deny() {
  jq -n --arg reason "$1" \
    '{ hookSpecificOutput: { hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason } }'
  exit 0
}

# Extract all command names from bash AST using shfmt
COMMANDS=$(shfmt --to-json <<< "$COMMAND" 2>/dev/null | jq -r '
  [
    (.. | objects | select(.Type == "CallExpr") | .Args[0]?.Parts[0]?.Value // empty),
    (.. | objects | select(.Type == "DeclClause") | .Variant.Value)
  ] | unique | .[]' 2>/dev/null)

# Fallback if shfmt fails
if [[ -z "$COMMANDS" ]]; then
  COMMANDS=$(echo "$COMMAND" | tr '|;&' '\n' | awk '{print $1}' | sort -u)
fi

# Blocked commands (ask for confirmation)
BLOCKED="@blockedCommands@"
for cmd in $COMMANDS; do
  cmd_base=$(basename "$cmd")
  for blocked in $BLOCKED; do
    if [[ "$cmd_base" == "$blocked" ]]; then
      block "${cmd_base} detected. Confirm with user before proceeding."
    fi
  done
done

# Denied subcommands (hard block)
DENIED_SUBCMDS="@deniedSubcommands@"
while IFS= read -r subcmd; do
  [[ -z "$subcmd" ]] && continue
  subcmd_re=$(echo "$subcmd" | sed 's/ /[[:space:]]+/g')
  if echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])${subcmd_re}([^a-zA-Z0-9_]|$)"; then
    deny "${subcmd} is not allowed."
  fi
done <<< "$DENIED_SUBCMDS"

# Blocked subcommands (ask for confirmation)
BLOCKED_SUBCMDS="@blockedSubcommands@"
while IFS= read -r subcmd; do
  [[ -z "$subcmd" ]] && continue
  subcmd_re=$(echo "$subcmd" | sed 's/ /[[:space:]]+/g')
  if echo "$COMMAND" | grep -qE "(^|[^a-zA-Z0-9_])${subcmd_re}([^a-zA-Z0-9_]|$)"; then
    block "${subcmd} detected. Confirm with user before proceeding."
  fi
done <<< "$BLOCKED_SUBCMDS"

# Catch piping remote content to shell/interpreter
PATTERNS="@blockedPatterns@"
while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  if echo "$COMMAND" | grep -qE "$pattern"; then
    block "Piping remote content to shell/interpreter. Confirm with user."
  fi
done <<< "$PATTERNS"

exit 0
