{ ... }:

{
  programs.fzf = {
    enable = true;

    defaultCommand = "fd --type f";
    defaultOptions = [
      "--layout=reverse"
      "--inline-info"
    ];
  };
}
