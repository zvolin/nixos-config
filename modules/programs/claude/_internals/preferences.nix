{ ... }:
{
  programs.claude-code.settings = {
    # Classic renderer keeps the transcript in the terminal's native scrollback.
    # The alt-screen renderer's incremental repaints desync inside zellij and
    # garble the pane on wheel-scroll; classic scrolls cleanly like codex and
    # keeps Alt+e EditScrollback working. Explicit value suppresses the prompt.
    tui = "default";

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
