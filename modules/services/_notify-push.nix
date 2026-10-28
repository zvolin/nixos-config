{
  pkgs,
  baseUrl ? null,
  credentialFile,
}:
let
  ntfy = import ./_ntfy-common.nix;
  serverUrl = if baseUrl == null then "http://nas:${toString ntfy.port}" else baseUrl;
in
{
  package = pkgs.writeShellApplication {
    name = "notify-push";
    runtimeInputs = [
      pkgs.curl
      pkgs.coreutils
    ];
    text = ''
      # usage: notify-push <title> <priority> <tags> <message>
      title=''${1:-Notification}
      priority=''${2:-default}
      tags=''${3:-}
      message=''${4:-}
      password=$(cat ${credentialFile})
      # Fire-and-forget: a push failure must never break the hook or the agent.
      # But a non-2xx (e.g. a 401 during credential bring-up) is logged to the
      # journal rather than silently swallowed.
      code=$(curl -sS --connect-timeout 2 --max-time 5 \
        -u "${ntfy.publisherUser}:$password" \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$message" \
        -o /dev/null -w '%{http_code}' \
        "${serverUrl}/${ntfy.agentTopic}") || code=000
      case "$code" in
        2??) ;;
        *) echo "notify-push: ntfy ${serverUrl}/${ntfy.agentTopic} returned $code" >&2 ;;
      esac
    '';
  };
}
