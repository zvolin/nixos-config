{
  pkgs,
  config,
}:
let
  realCodex = config.programs.codex.package;

  codexWrap = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = with pkgs; [
      coreutils
    ];
    text = ''
      realcodex=${realCodex}/bin/codex

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

      # `< /dev/null` closes stdin so codex cannot block waiting on it; stderr
      # is captured for post-mortem. This is the last command, so its exit
      # status becomes the wrapper's (writeShellApplication runs under `set -e`).
      exec "$realcodex" "$@" 2> "$run_dir/stderr" < /dev/null
    '';
  };
in
{
  inherit codexWrap;
}
