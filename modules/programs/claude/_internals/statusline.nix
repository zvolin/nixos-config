{ pkgs, ... }:
let
  jq = "${pkgs.jq}/bin/jq";
  git = "${pkgs.git}/bin/git";
  date = "${pkgs.coreutils}/bin/date";

  statuslineScript = pkgs.writeShellScript "claude-statusline" ''
    input=$(cat)

    model=$(echo "$input" | ${jq} -r '.model.id // .model.display_name // ""')
    # Branch from git, not .worktree.branch (which is populated only in
    # --worktree sessions). Shell git in the reported working dir; the store
    # path is pinned because the script has no guaranteed PATH.
    current_dir=$(echo "$input" | ${jq} -r '.workspace.current_dir // ""')
    branch=$(${git} -C "$current_dir" branch --show-current 2>/dev/null)
    ctx_pct=$(echo "$input" | ${jq} -r '.context_window.used_percentage // 0 | floor')
    ctx_input=$(echo "$input" | ${jq} -r '.context_window.current_usage.input_tokens // 0')
    ctx_cache_create=$(echo "$input" | ${jq} -r '.context_window.current_usage.cache_creation_input_tokens // 0')
    ctx_cache_read=$(echo "$input" | ${jq} -r '.context_window.current_usage.cache_read_input_tokens // 0')
    ctx_used=$(( ctx_input + ctx_cache_create + ctx_cache_read ))
    ctx_total=$(echo "$input" | ${jq} -r '.context_window.context_window_size // 0')

    # Rate-limit windows, one jq call per window. Floor at read:
    # used_percentage is a float on the wire and bash integer arithmetic
    # crashes on a raw float. Emitting both fields as a TSV row (rather than
    # two separate `// empty` reads) means an absent field becomes an empty
    # string instead of a dropped array element, so the two fields can never
    # come out misaligned.
    IFS=$'\t' read -r five_hour_pct five_hour_reset <<< "$(echo "$input" | ${jq} -r '
      [(.rate_limits.five_hour.used_percentage | if . == null then null else floor end),
       (.rate_limits.five_hour.resets_at // null)] | @tsv')"
    IFS=$'\t' read -r seven_day_pct seven_day_reset <<< "$(echo "$input" | ${jq} -r '
      [(.rate_limits.seven_day.used_percentage | if . == null then null else floor end),
       (.rate_limits.seven_day.resets_at // null)] | @tsv')"

    now=$(${date} +%s)

    RST='\033[0m'
    DIM='\033[2m'
    BOLD='\033[1m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    RED='\033[31m'

    # Shared threshold coloring: green ≤50, yellow ≤80, red >80.
    # Caller must pass a floored integer (both call sites do).
    pct_color() {
      local p=$1
      if (( p <= 50 )); then echo "$GREEN"
      elif (( p <= 80 )); then echo "$YELLOW"
      else echo "$RED"
      fi
    }

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

    # Compact reset countdown: ≥1d → 3d4h, ≥1h → 2h13m, else 45m
    fmt_eta() {
      local secs=$1
      local days=$(( secs / 86400 ))
      local hours=$(( (secs % 86400) / 3600 ))
      local mins=$(( (secs % 3600) / 60 ))
      if (( days >= 1 )); then echo "''${days}d''${hours}h"
      elif (( hours >= 1 )); then echo "''${hours}h''${mins}m"
      else echo "''${mins}m"
      fi
    }

    # Render one rate-limit segment. Percentage carries the color; ETA is dim.
    # A past/zero reset delta drops the ETA but keeps the util%.
    fmt_limit() {
      local label=$1
      local pct=$2
      local resets=$3
      local color
      local seg
      color=$(pct_color "$pct")
      seg="''${label} ''${color}''${pct}%''${RST}"
      if [[ -n "$resets" ]]; then
        local delta=$(( resets - now ))
        if (( delta > 0 )); then
          seg+=" ''${DIM}$(fmt_eta "$delta")''${RST}"
        fi
      fi
      echo "$seg"
    }

    sep="''${DIM} · ''${RST}"
    out="''${BOLD}''${model}''${RST}"

    # Git branch
    if [[ -n "$branch" ]]; then
      out+="''${sep}''${branch}"
    fi

    # Context bar
    if (( ctx_pct > 0 )); then
      color=$(pct_color "$ctx_pct")
      filled=$(( ctx_pct * 6 / 100 ))
      empty=$(( 6 - filled ))
      bar=""
      for ((i=0; i<filled; i++)); do bar+="█"; done
      for ((i=0; i<empty; i++)); do bar+="░"; done
      used_fmt=$(fmt_tokens "$ctx_used")
      total_fmt=$(fmt_tokens "$ctx_total")
      out+="''${sep}''${color}''${bar}''${RST} ''${ctx_pct}% (''${used_fmt} / ''${total_fmt})"
    fi

    # Rate-limit segments (Pro/Max only, present after the first API response)
    if [[ -n "$five_hour_pct" ]]; then
      out+="''${sep}$(fmt_limit 5h "$five_hour_pct" "$five_hour_reset")"
    fi
    if [[ -n "$seven_day_pct" ]]; then
      out+="''${sep}$(fmt_limit 7d "$seven_day_pct" "$seven_day_reset")"
    fi

    printf '%b' "$out"
  '';
in
{
  programs.claude-code.settings.statusLine = {
    type = "command";
    command = "${statuslineScript}";
    padding = 0;
    # Event-driven otherwise; without a refresh the reset ETA freezes while
    # idle. 60s keeps the minute-granularity countdown accurate; re-runs the
    # local render only, no network.
    refreshInterval = 60;
  };
}
