{ config, ... }:
let
  # --- Deny list ---
  home = config.home.homeDirectory;
  expandTilde = path: builtins.replaceStrings [ "~" ] [ home ] path;

  # No Write(path) rule: Claude Code's file-permission check only matches
  # Read(path) and Edit(path), and Edit covers every file-editing tool
  # (Write, Edit, NotebookEdit). A Write(path) rule is inert and makes the
  # CLI warn about it on every launch.
  mkPathDeny = path: [
    "Read(${path})"
    "Edit(${path})"
  ];

  mkDirDeny = dir: mkPathDeny "${expandTilde dir}/**";
  mkFileDeny = file: mkPathDeny (expandTilde file);

  deniedDirectories = [
    "~/.ssh"
    "~/.aws"
    "~/.kube"
    "~/.gnupg"
    "~/.config/sops"
    "~/.config/gh" # sandbox allows gh CLI read; denied for Claude's Read/Edit
    "~/.config/gcloud"
    "~/.config/BraveSoftware"
    "~/.mozilla"
    "~/.config/Signal"
    "~/.config/discord"
    "~/.config/Element"
    "~/.local/share/TelegramDesktop"
    "~/.local/share/atuin"
    "~/.local/share/keyrings" # sandbox allows dbus/keyring access; denied for Claude's tools
  ];

  deniedFiles = [
    "~/.netrc"
    "~/.npmrc"
    "~/.pypirc"
    "~/.docker/config.json"
    "~/.zsh_history"
    "~/.bash_history"
  ];

  deniedAbsolutePaths = [
    "/run/secrets/**"
  ];

  denyList =
    (builtins.concatMap mkDirDeny deniedDirectories)
    ++ (builtins.concatMap mkFileDeny deniedFiles)
    ++ (builtins.concatMap mkPathDeny deniedAbsolutePaths)
    ++ [
      # Denied bash commands (fallback if bash hook fails)
      "Bash(git push *)"
      "Bash(git push)"
    ];
in
{
  programs.claude-code.settings.permissions.deny = denyList;
}
