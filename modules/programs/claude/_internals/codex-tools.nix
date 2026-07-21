{
  pkgs,
  lib,
  jail,
}:
let
  codex = jail.clients.codex;
  callerMarker = jail.clients.claude.markerEnv;
  unleashStr = lib.escapeShellArgs codex.unleashFlags;

  codexWrap = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = with pkgs; [ coreutils ];
    text = ''
      # This shim runs the RAW codex binary unleashed, with no own bwrap — the
      # outer Claude jail is the only containment. Refuse to run if we are not
      # inside it (fail-closed: unleashed <=> contained).
      if [ -z "''${${callerMarker}:-}" ]; then
        echo "codex bridge: refusing to run unleashed outside Claude's jail (${callerMarker} unset)" >&2
        exit 1
      fi

      realcodex=${codex.rawBinary}

      # Walk the ORIGINAL argv to classify the invocation (does not gate flag
      # injection — flags are injected globally below; this only decides whether
      # to apply the stdin-close + logdir treatment).
      saw_exec=0
      is_resume=0
      args=("$@")
      n=''${#args[@]}
      i=0
      while [ "$i" -lt "$n" ]; do
        a="''${args[$i]}"
        i=$((i + 1))
        if [ "$saw_exec" = "0" ]; then
          [ "$a" = "exec" ] && saw_exec=1
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

      # Non-resume `codex exec`: close stdin (codex always reads it and would
      # block), capture stderr, log per-run artifacts.
      if [ "$saw_exec" = "1" ] && [ "$is_resume" = "0" ]; then
        run_dir=''${CODEX_LOGDIR:-/tmp/codex-runs}/$(date +%Y%m%d-%H%M%S)-$$
        mkdir -p "$run_dir"
        exec "$realcodex" ${unleashStr} "$@" 2> "$run_dir/stderr" < /dev/null
      fi

      # Everything else (resume, non-exec subcommands): passthrough with stdin
      # left open. Flags are still injected globally.
      exec "$realcodex" ${unleashStr} "$@"
    '';
  };
in
{
  inherit codexWrap;
}
