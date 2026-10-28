{ pkgs, credentialFile }:
let
  ntfy = import ./_ntfy-common.nix;
in
rec {
  topic = ntfy.healthTopic;

  package = pkgs.writeShellApplication {
    name = "nas-health-push";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      # usage: nas-health-push <title> <priority> <tags> <message>
      title=''${1:-nas-health}
      priority=''${2:-default}
      tags=''${3:-}
      message=''${4:-}
      password=$(cat ${credentialFile})
      # Safety-critical: a failed push exits non-zero (unlike the fire-and-forget agent-events helper).
      code=$(curl -sS --connect-timeout 2 --max-time 5 \
        -u "${ntfy.publisherUser}:$password" \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$message" \
        -o /dev/null -w '%{http_code}' \
        "http://127.0.0.1:${toString ntfy.port}/${ntfy.healthTopic}") || code=000
      case "$code" in
        2??) ;;
        *)
          echo "nas-health-push: ntfy returned $code" >&2
          exit 1
          ;;
      esac
    '';
  };
}
