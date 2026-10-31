{ ... }:
{
  programs.claude-code.settings = {
    # Classic renderer streams the transcript into native scrollback, so
    # zellij Alt-s/Alt-e reach the whole session; "fullscreen" repaints the
    # alt-screen, leaving only the viewport. >=2.1 dropped "default" (it
    # silently fell back to fullscreen) for "classic"/"fullscreen".
    tui = "classic";

    # Drop attribution from commits and PRs. Empty strings hide the
    # Co-Authored-By byline (supersedes the old includeCoAuthoredBy setting);
    # sessionUrl = false drops the claude.ai session link that web / Remote
    # Control commits would otherwise append.
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
