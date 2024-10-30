{ ... }:

{
  programs.git = {
    enable = true;
    signing.key = "9DD9C8FD06750734";
    signing.signByDefault = true;
  };
}
