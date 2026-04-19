{ pkgs, ... }:

let
  jq = "${pkgs.jq}/bin/jq";

  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    model=$(echo "$input" | ${jq} -r '.model.id // .model.display_name // ""')
    branch=$(echo "$input" | ${jq} -r '.worktree.branch // ""')
    ctx_pct=$(echo "$input" | ${jq} -r '.context_window.used_percentage // 0 | floor')
    ctx_input=$(echo "$input" | ${jq} -r '.context_window.current_usage.input_tokens // 0')
    ctx_cache_create=$(echo "$input" | ${jq} -r '.context_window.current_usage.cache_creation_input_tokens // 0')
    ctx_cache_read=$(echo "$input" | ${jq} -r '.context_window.current_usage.cache_read_input_tokens // 0')
    ctx_used=$(( ctx_input + ctx_cache_create + ctx_cache_read ))
    ctx_total=$(echo "$input" | ${jq} -r '.context_window.context_window_size // 0')

    RST='\033[0m'
    DIM='\033[2m'
    BOLD='\033[1m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    RED='\033[31m'

    # Format token count as "123k" or "1.2M"
    fmt_tokens() {
      local n=$1
      if (( n >= 1000000 )); then
        local whole=$(( n / 1000000 ))
        local frac=$(( (n % 1000000) / 100000 ))
        if (( frac > 0 )); then
          echo "''${whole}.''${frac}M"
        else
          echo "''${whole}M"
        fi
      elif (( n >= 1000 )); then
        echo "$(( n / 1000 ))k"
      else
        echo "$n"
      fi
    }

    sep="''${DIM} · ''${RST}"
    out="''${BOLD}''${model}''${RST}"

    # Git branch
    if [[ -n "$branch" ]]; then
      out+="''${sep}''${branch}"
    fi

    # Context bar
    if (( ctx_pct > 0 )); then
      if (( ctx_pct <= 50 )); then color="$GREEN"
      elif (( ctx_pct <= 80 )); then color="$YELLOW"
      else color="$RED"
      fi
      filled=$(( ctx_pct * 6 / 100 ))
      empty=$(( 6 - filled ))
      bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done
      used_fmt=$(fmt_tokens "$ctx_used")
      total_fmt=$(fmt_tokens "$ctx_total")
      out+="''${sep}''${color}''${bar}''${RST} ''${ctx_pct}% (''${used_fmt} / ''${total_fmt})"
    fi

    printf '%b' "$out"
  '';
in
{
  programs.claude-code.settings.statusLine = {
    type = "command";
    command = "${statuslineScript}";
    padding = 0;
  };
}
