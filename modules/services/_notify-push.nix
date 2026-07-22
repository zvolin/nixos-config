# Shared ntfy push helper (port, topic, and the notify-push binary).
# Underscore-prefixed so import-tree skips auto-discovery (this is a plain
# builder, not a flake module); the ntfy server module and both AI CLI hook
# wirings `import` this directly.
{ pkgs }:
rec {
  # Single ntfy topic for all agent events; the notification title (client +
  # session name) disambiguates the source. Port and topic are defined once
  # here; the ntfy server module and every hook caller import this.
  port = 2586;
  topic = "agents";

  package = pkgs.writeShellApplication {
    name = "notify-push";
    runtimeInputs = [ pkgs.curl ];
    text = ''
      # usage: notify-push <title> <priority> <tags> <message>
      title=''${1:-Notification}
      priority=''${2:-default}
      tags=''${3:-}
      message=''${4:-}
      # Fire-and-forget: a push failure must never break the hook or the agent.
      curl -fsS \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$message" \
        "http://127.0.0.1:${toString port}/${topic}" >/dev/null || true
    '';
  };
}
