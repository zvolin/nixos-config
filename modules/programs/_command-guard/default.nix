# Shared bash-command guard for the AI CLIs (Claude, Codex). Underscore-prefixed
# so import-tree skips auto-discovery; both clients `import ../_command-guard`
# directly (Claude via _internals/security.nix, Codex via default.nix). Single
# source of truth for the three blocklists, the shfmt-AST guard script, and the
# Codex `forbidden` prefix-rule floor, so the two guards can never drift.
{ pkgs, lib }:
let
  blockedCommands = [
    "sudo"
    "doas"
    "eval"
    "dd"
    "mkfs"
    "shred"
  ];
  deniedSubcommands = [
    "git push"
    "git push --force"
    "git push -f"
  ];
  blockedPatterns = [
    "curl|sh"
    "curl|bash"
    "wget|sh"
    "wget|bash"
    "curl|python"
    "wget|python"
  ];

  blockedCommandsStr = builtins.concatStringsSep " " blockedCommands;
  deniedSubcommandsStr = builtins.concatStringsSep "\n" deniedSubcommands;

  # Convert "source|sink" shorthand to "source.*\|.*sink" grep regex
  patternToRegex =
    pattern:
    let
      parts = builtins.split "\\|" pattern;
      source = builtins.elemAt parts 0;
      sink = builtins.elemAt parts 2;
    in
    "${source}.*\\|.*${sink}";

  blockedPatternsStr = builtins.concatStringsSep "\n" (map patternToRegex blockedPatterns);

  # Build the wrapped guard script. `softDecision` is the permissionDecision the
  # soft-block path (`block()`) emits: "ask" on Claude (a prompt), "deny" on
  # Codex (a hard refusal, because Codex treats "ask" as unsupported for
  # PreToolUse and fails open). `deny()` is already a hard "deny" on both.
  mkGuardScript =
    { name, softDecision }:
    let
      # Soft-block reason text varies by client: Claude prompts the user, so
      # "confirm with user" is actionable; Codex runs under never-ask and turns
      # this path into a hard refusal, where telling the agent to confirm would
      # be misleading advice it can't follow.
      isAsk = softDecision == "ask";
      softBlockReasonCmd = if isAsk then "Confirm with user before proceeding." else "Not permitted.";
      softBlockReasonPipe = if isAsk then "Confirm with user." else "Not permitted.";
      src =
        builtins.replaceStrings
          [
            "@blockedCommands@"
            "@deniedSubcommands@"
            "@blockedPatterns@"
            "@softDecision@"
            "@softBlockReasonCmd@"
            "@softBlockReasonPipe@"
          ]
          [
            blockedCommandsStr
            deniedSubcommandsStr
            blockedPatternsStr
            softDecision
            softBlockReasonCmd
            softBlockReasonPipe
          ]
          (builtins.readFile ./check-bash-command.sh);
      script = pkgs.writeShellScriptBin name src;
    in
    pkgs.symlinkJoin {
      inherit name;
      paths = [ script ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${name} \
          --prefix PATH : ${
            lib.makeBinPath [
              pkgs.shfmt
              pkgs.jq
              pkgs.coreutils
              pkgs.gnugrep
              pkgs.gawk
            ]
          }
      '';
    };

  # Codex `forbidden` prefix-rule floor beneath the hook. One rule per entry of
  # blockedCommands ++ deniedSubcommands, generated from the shared lists so it
  # can never become a hand-maintained parallel subset. Each entry is tokenized
  # on whitespace: a Codex prefix_rule matches argv element-wise, so "git push"
  # MUST render as ["git", "push"], never one "git push" element (which would
  # never match argv[0]="git"). blockedPatterns are excluded, being pipes that
  # are not prefix-expressible.
  forbiddenEntries = blockedCommands ++ deniedSubcommands;

  renderForbiddenRule =
    entry:
    let
      tokens = lib.splitString " " entry;
      quoted = map (t: ''"${t}"'') tokens;
    in
    # An entry must tokenize into non-empty argv elements. `splitString " "`
    # yields an empty "" element for any doubled, leading, or trailing space, and
    # that would silently render a broken rule like ["git", "", "push"] into the
    # security floor. Fail the build on it so a malformed list entry is an
    # authoring error you see, not a hole you ship.
    assert lib.assertMsg (lib.all (t: t != "") tokens)
      "forbiddenRules: entry '${entry}' tokenized to an empty element (check for doubled/leading/trailing spaces)";
    ''prefix_rule(pattern=[${builtins.concatStringsSep ", " quoted}], decision="forbidden")'';

  forbiddenRules = builtins.concatStringsSep "\n" (map renderForbiddenRule forbiddenEntries);
in
{
  # Exposed as the source-of-truth lists so a future guard can build on them;
  # in-repo consumers today only reach for mkGuardScript and forbiddenRules.
  inherit
    blockedCommands
    deniedSubcommands
    blockedPatterns
    mkGuardScript
    forbiddenRules
    ;
}
