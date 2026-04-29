{config, ...}: let
  # --- Deny list ---
  home = config.home.homeDirectory;
  expandTilde = path: builtins.replaceStrings ["~"] [home] path;

  mkDenyTriple = path: [
    "Read(${path})"
    "Write(${path})"
    "Edit(${path})"
  ];

  mkDirDeny = dir: mkDenyTriple "${expandTilde dir}/**";
  mkFileDeny = file: mkDenyTriple (expandTilde file);

  deniedDirectories = [
    "~/.ssh"
    "~/.aws"
    "~/.kube"
    "~/.gnupg"
    "~/.config/sops"
    "~/.config/gh" # sandbox allows gh CLI read; denied for Claude's Read/Write/Edit
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
    ++ (builtins.concatMap mkDenyTriple deniedAbsolutePaths)
    ++ [
      # Denied bash commands (fallback if bash hook fails)
      "Bash(git push *)"
      "Bash(git push)"
    ];
in {
  programs.claude-code.settings.permissions.deny = denyList;
}
