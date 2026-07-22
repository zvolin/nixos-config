{ ... }:
{
  flake.modules.homeManager.git =
    { pkgs, lib, ... }:
    let
      signingKey = "9DD9C8FD06750734";

      prePushHook = pkgs.writeShellApplication {
        name = "git-pre-push-signing-guard";
        runtimeInputs = [ pkgs.git ];
        text = ''
          SIGNING_KEY="${signingKey}"
          NULL_OID_RE='^0+$'
          remote_name="$1"

          resolve_default_branch() {
            local remote_output key value local_symref
            if remote_output="$(git ls-remote --symref "$remote_name" HEAD 2>/dev/null)"; then
              while read -r key value _; do
                if [ "$key" = "ref:" ]; then
                  printf '%s\n' "''${value#refs/heads/}"
                  return 0
                fi
              done <<< "$remote_output"
            fi
            if local_symref="$(git symbolic-ref "refs/remotes/$remote_name/HEAD" 2>/dev/null)"; then
              printf '%s\n' "''${local_symref#refs/remotes/"$remote_name"/}"
            fi
            return 0
          }

          commit_signed_by_user() {
            local sigstatus="$1" signer_fpr="$2" primary_fpr="$3"
            case "$sigstatus" in
              G | U) ;;
              *) return 1 ;;
            esac
            case "$signer_fpr" in *"$SIGNING_KEY") return 0 ;; esac
            case "$primary_fpr" in *"$SIGNING_KEY") return 0 ;; esac
            return 1
          }

          default_branch="$(resolve_default_branch)"
          exit_code=0
          failed_commits=""

          # Reads/writes default_branch, exit_code and failed_commits from the
          # enclosing scope instead of taking/returning them explicitly.
          check_ref_signing() {
            local local_oid="$1" remote_ref="$2" remote_oid="$3"
            local pushed_branch range commits sha sigstatus signer_fpr primary_fpr

            pushed_branch="''${remote_ref#refs/heads/}"
            [ -n "$default_branch" ] && [ "$pushed_branch" != "$default_branch" ] && return 0
            if [ -z "$default_branch" ]; then
              case "$pushed_branch" in
                main | master) ;;
                *) return 0 ;;
              esac
            fi

            if [[ "$remote_oid" =~ $NULL_OID_RE ]]; then
              range=("$local_oid" --not --remotes)
            else
              range=("$remote_oid..$local_oid")
            fi

            if ! commits="$(git log --format='%H %G? %GF %GP' "''${range[@]}" 2>/dev/null)"; then
              failed_commits="$failed_commits  (cannot resolve range for $pushed_branch)"$'\n'
              exit_code=1
              return 0
            fi
            while read -r sha sigstatus signer_fpr primary_fpr; do
              if [ -z "$sha" ]; then
                continue
              fi
              if ! commit_signed_by_user "$sigstatus" "$signer_fpr" "$primary_fpr"; then
                failed_commits="$failed_commits  $sha"$'\n'
                exit_code=1
              fi
            done <<< "$commits"
          }

          while read -r _ local_oid remote_ref remote_oid; do
            if [[ "$local_oid" =~ $NULL_OID_RE ]]; then
              continue
            fi
            check_ref_signing "$local_oid" "$remote_ref" "$remote_oid"
          done

          if [ "$exit_code" -ne 0 ]; then
            {
              echo "pre-push: refusing to add unsigned or wrong-key commits to the default branch."
              echo "Offending commits (must be signed with key $SIGNING_KEY):"
              printf '%s' "$failed_commits"
              echo
              echo "Re-sign, e.g.:  git rebase --exec 'git commit --amend --no-edit -S' <base>..HEAD"
              echo "Override deliberately:  git push --no-verify"
            } >&2
          fi

          exit "$exit_code"
        '';
      };

      hooksDir = pkgs.runCommand "git-hooks" { } ''
        mkdir -p "$out"
        ln -s ${lib.getExe prePushHook} "$out/pre-push"
      '';
    in
    {
      programs.git = {
        enable = true;

        settings.user = {
          name = "zvolin";
          email = "mac.zwolinski@gmail.com";
        };

        settings.core.hooksPath = "${hooksDir}";
        settings.gpg.program = lib.getExe pkgs.gnupg;

        ignores = [
          "**/.claude/"
          "**/.worktrees"
          "**/docs/plans/"
          "**/docs/insights/"
          "**/docs/superpowers/"
          "**/docs/LLM_CONTEXT.md"
          "**/docs/architecture-reports/"
          "**/.serena/"
          "**/.direnv"
          "**/.envrc"
          "**/CLAUDE.local.md"
          "**/HANDOFF.md"
          "**/AGENTS.md"
          "**/AGENTS.override.md"
          "**/.agents/"
          "**/.codex"
        ];

        signing.key = signingKey;
        signing.signByDefault = true;
        signing.format = "openpgp";
      };
    };
}
