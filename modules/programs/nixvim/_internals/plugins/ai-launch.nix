{ pkgs }:
pkgs.writeShellScriptBin "ai-launch" ''
  set -u

  id="$1"
  project="$2"

  agent=$(printf '%s\n' claude codex \
    | ${pkgs.fzf}/bin/fzf \
        --layout=reverse --border=rounded --padding=1 \
        --margin=1,20% --info=hidden --no-scrollbar \
        --header="new AI tab #$id") || exit 0

  [ -n "$agent" ] || exit 0

  if [ -n "''${NVIM:-}" ]; then
    ${pkgs.neovim}/bin/nvim --server "$NVIM" \
      --remote-expr "v:lua.ai_rename($id, '$agent')" >/dev/null 2>&1 || true
  fi

  if [ "$agent" = "claude" ]; then
    export CLAUDE_SESSION_NAME="vim:$project #$id"
  fi

  exec "$agent"
''
