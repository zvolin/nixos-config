{ pkgs, lib }:
let
  binPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gnused
    pkgs.git
    pkgs.zellij
    pkgs.fzf
  ];
in
pkgs.writeShellScriptBin "ai-launch" ''
  set -u
  export PATH=${binPath}:$PATH

  root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  project=$(basename "$root")

  id=$(zellij action query-tab-names 2>/dev/null \
    | sed -n 's/^\(claude\|codex\)-\([0-9]\+\)$/\2/p' \
    | sort -n | tail -1)
  id=$(( ''${id:-0} + 1 ))

  agent=$(printf '%s\n' claude codex \
    | fzf \
        --layout=reverse --border=rounded --padding=1 \
        --margin=1,20% --info=hidden --no-scrollbar \
        --header="new AI tab #$id") || exit 0

  [ -n "$agent" ] || exit 0

  if [ -n "''${ZELLIJ:-}" ]; then
    zellij action rename-tab "$agent-$id" >/dev/null 2>&1 || true
  fi

  export AI_SESSION_PROJECT="$project"
  export AI_SESSION_TAB="$id"

  exec "$agent"
''
