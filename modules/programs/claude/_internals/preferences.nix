{ ... }:
{
  programs.claude-code.settings = {
    # Flicker-free alt-screen renderer (mouse support, auto-copy). Stops the
    # "try the new renderer?" launch prompt from reappearing each start.
    tui = "fullscreen";

    # Suppress the Co-Authored-By / attribution byline on commits and PRs.
    # Empty string hides attribution; the modern replacement for the
    # deprecated includeCoAuthoredBy setting. sessionUrl = false also drops
    # the claude.ai session link that web/Remote Control commits would append.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
