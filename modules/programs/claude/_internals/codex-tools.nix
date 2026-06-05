{
  pkgs,
  config,
}:
let
  realCodex = config.programs.codex.package;

  codexWatch = pkgs.writeShellApplication {
    name = "codex-watch";
    runtimeInputs = with pkgs; [
      iproute2
      gawk
      gnugrep
      coreutils
    ];
    text = ''
      pid=''${1:?usage: codex-watch <pid> [logfile]}
      logfile=''${2:-/tmp/codex-watch-$pid.log}

      sample_cpu() {
        awk '{print $14+$15}' "/proc/$pid/stat" 2>/dev/null
      }
      sample_rchar() {
        awk '/^rchar:/{print $2}' "/proc/$pid/io" 2>/dev/null || echo 0
      }
      sample_tcp() {
        pat="pid=''${pid}[,)]"
        ss -tnp 2>/dev/null | grep -c "$pat" || true
      }

      sleep 30
      last_rchar=$(sample_rchar)

      while kill -0 "$pid" 2>/dev/null; do
        t0=$(sample_cpu) || break
        sleep 3
        t1=$(sample_cpu) || break
        cpu=$((t1 - t0))

        tcp=$(sample_tcp)
        rchar=$(sample_rchar)
        rchar_delta=$((rchar - last_rchar))
        last_rchar=$rchar

        status="ok"
        if [ "$cpu" = "0" ] && [ "$tcp" = "0" ] && [ "$rchar_delta" = "0" ]; then
          status="HANG?"
        fi

        printf '%s pid=%s cpu=%s tcp=%s rchar_delta=%s %s\n' \
          "$(date -Iseconds)" "$pid" "$cpu" "$tcp" "$rchar_delta" "$status" \
          >> "$logfile"

        sleep 300
      done

      printf '%s pid=%s EXITED\n' "$(date -Iseconds)" "$pid" >> "$logfile"
    '';
  };

  codexWrap = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      realcodex=${realCodex}/bin/codex
      watch=${codexWatch}/bin/codex-watch

      # Walk argv to find the `exec` subcommand and the first non-flag
      # positional after it. Global options can sit before `exec`
      # (e.g. `codex -c key=val exec ...`). Resume can sit after exec-options
      # (e.g. `codex exec --skip-git-repo-check resume --last`).
      saw_exec=0
      is_resume=0
      exec_pos=0
      args=("$@")
      n=''${#args[@]}
      i=0
      while [ "$i" -lt "$n" ]; do
        a="''${args[$i]}"
        i=$((i + 1))
        if [ "$saw_exec" = "0" ]; then
          if [ "$a" = "exec" ]; then
            saw_exec=1
            exec_pos=$((i - 1))
          fi
          continue
        fi
        case "$a" in
          --*=*) continue ;;
          -c|--config|--enable|--disable|-i|--image|-m|--model|--local-provider|-s|--sandbox|-p|--profile|-C|--cd|--add-dir|--output-schema|--color|-o|--output-last-message)
            i=$((i + 1)); continue ;;
          --*|-?) continue ;;
          *)
            [ "$a" = "resume" ] && is_resume=1
            break ;;
        esac
      done

      if [ "$saw_exec" = "0" ]; then
        exec "$realcodex" "$@"
      fi

      if [ "$is_resume" = "1" ]; then
        exec "$realcodex" "$@"
      fi

      sandbox_set=0
      for arg in "''${args[@]:exec_pos+1}"; do
        case "$arg" in
          --sandbox|--sandbox=*|-s|--full-auto) sandbox_set=1 ;;
        esac
      done

      if [ "$sandbox_set" = "0" ]; then
        pre=("''${args[@]:0:exec_pos+1}")
        post=("''${args[@]:exec_pos+1}")
        set -- "''${pre[@]}" --sandbox read-only "''${post[@]}"
      fi

      run_dir=''${CODEX_LOGDIR:-/tmp/codex-runs}/$(date +%Y%m%d-%H%M%S)-$$
      mkdir -p "$run_dir"

      "$realcodex" "$@" 2> "$run_dir/stderr" < /dev/null &
      codex_pid=$!
      echo "$codex_pid" > "$run_dir/pid"

      "$watch" "$codex_pid" "$run_dir/watch.log" &
      watch_pid=$!

      wait "$codex_pid"
      status=$?

      kill "$watch_pid" 2>/dev/null || true
      wait "$watch_pid" 2>/dev/null || true
      exit "$status"
    '';
  };
in
{
  inherit codexWrap;
}
