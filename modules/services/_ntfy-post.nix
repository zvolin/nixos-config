{
  pkgs,
  ntfy, # the facts seam (inputs.self.lib.ntfy), passed by the aspect
  isServer ? false, # this host runs the ntfy server → post to loopback
  credentialFile, # file fallback for the cred (out-of-jail producers)
}:
let
  base =
    if isServer then
      "http://127.0.0.1:${toString ntfy.port}"
    else
      "http://${ntfy.host}:${toString ntfy.port}";
in
{
  package = pkgs.writeShellApplication {
    name = "ntfy-post";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      # usage: ntfy-post <topic> <title> <priority> <tags> <message>
      topic=''${1:?ntfy-post: topic required}
      title=''${2:-Notification}
      priority=''${3:-default}
      tags=''${4:-}
      message=''${5:-}
      # Fail-mode derived from topic: a caller can't downgrade nas-health.
      case "$topic" in
        ${ntfy.topics.health}) strict=1 ;;
        *) strict=0 ;;
      esac
      # Cred from env (AI jail preloads it) or file (out-of-jail producers).
      password=''${NTFY_PUBLISHER_PASSWORD:-}
      if [ -z "$password" ]; then
        password=$(cat ${credentialFile} 2>/dev/null || true)
      fi
      code=$(curl -sS --connect-timeout 2 --max-time 5 \
        -u "${ntfy.users.publisher}:$password" \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$message" \
        -o /dev/null -w '%{http_code}' \
        "${base}/$topic") || code=000
      # 'if', not '[ … ] && exit 1': as the arm's last command the latter would leak the test's non-zero status.
      case "$code" in
        2??) ;;
        *)
          echo "ntfy-post: ntfy ${base}/$topic returned $code" >&2
          if [ "$strict" = 1 ]; then
            exit 1
          fi
          ;;
      esac
    '';
  };
}
