{ ... }:
{
  programs.claude-code.settings = {
    # Flicker-free alt-screen renderer. Also stops the "try the new renderer?"
    # prompt from reappearing at every launch.
    tui = "fullscreen";

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
