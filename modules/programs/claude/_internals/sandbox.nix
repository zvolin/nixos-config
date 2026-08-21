{
  pkgs,
  lib,
  ...
}:
let
  jail = import ../../_jail.nix { inherit pkgs lib; };
  codexTools = import ./codex-tools.nix { inherit pkgs lib jail; };

  # A WHITELIST: anything not listed here stays per-account, including whatever
  # a future Claude Code version adds. Nothing derives this from Home Manager's
  # file set, so a new ~/.claude/<x> has to be added by hand or the second
  # account silently will not see it.
  sharedDirs = [
    "agents"
    "skills"
    "rules"
    "plugins" # the MCP servers (context7, nixos) live here
    "projects" # transcripts for --resume, and native auto-memory
    "plans"
    "teams"
    "tasks"
    "file-history"
    "shell-snapshots"
    "paste-cache"
    "session-env" # UUID-keyed, so no cross-instance collision
    "cache" # changelog and closed-issues, both account-neutral
  ];

  # Bind-only, never pre-created: CLAUDE.md and settings.json are Home Manager
  # store symlinks, and planting a plain file at one breaks the next
  # `nixos-rebuild switch`.
  #
  # Each of these is its own mount point, so a writer that renames over it gets
  # EBUSY where a file inside a bound directory would have worked. Retiring an
  # entry means dropping it here AND deleting the stub bwrap left at
  # ~/.claude-alt/<file>, or claude2 reads an empty file instead of none.
  sharedFiles = [
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "history.jsonl" # up-arrow prompt recall
  ];

  # The base must come first: it mounts at $HOME/.claude, and every shared entry
  # binds on top of it. Sources stay host paths, so they still resolve against
  # the real ~/.claude afterwards.
  altBinds =
    base:
    [
      {
        source = base;
        target = ".claude";
        kind = "dir";
        required = true;
        preCreate = true;
      }
      {
        source = "${base}/.claude.json";
        target = ".claude.json";
        kind = "file";
        required = true;
        preCreate = true;
      }
    ]
    ++ map (d: {
      source = ".claude/${d}";
      target = ".claude/${d}";
      kind = "dir";
      preCreate = true;
    }) sharedDirs
    ++ map (f: {
      source = ".claude/${f}";
      target = ".claude/${f}";
      kind = "file";
    }) sharedFiles;

  # altBase == null is the primary account: ~/.claude and ~/.claude.json bind at
  # their own paths, as they did before a second profile existed.
  mkClaudeJail =
    {
      name,
      altBase ? null,
    }:
    jail.mkJail {
      inherit name;
      policy = jail.clients.claude;
      preCreateDirs = lib.optional (altBase == null) ".claude" ++ [
        ".codex"
        ".agents"
      ];
      preCreateFiles = lib.optional (altBase == null) ".claude.json";
      extraEnv = [
        "AI_SESSION_PROJECT"
        "AI_SESSION_TAB"
      ];
      pathPrefix = [ codexTools.codexWrap ];
      extraBinds = lib.optionals (altBase != null) (altBinds altBase);
      configFile = if altBase == null then null else "${altBase}/.claude.json";
    };

  claudeJail = mkClaudeJail { name = "claude"; };

  # No .credentials.json is pre-created: an absent file starts the login flow
  # cleanly where a zero-byte one risks the parser. .claude.json is, because the
  # trust prelude's `[ -s "$f" ] || echo '{}' > "$f"` seeds valid JSON into it.
  claude2Jail = mkClaudeJail {
    name = "claude2";
    altBase = ".claude-alt";
  };

  claude-wrapped = claudeJail.wrapper // {
    inherit (pkgs.claude-code) version;
    meta = (pkgs.claude-code.meta or { }) // {
      mainProgram = "claude";
    };
  };
in
{
  programs.claude-code.package = claude-wrapped;
  home.packages = [ claude2Jail.wrapper ];
}
