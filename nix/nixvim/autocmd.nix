{ ... }:

{
  programs.nixvim.autoCmd = [
    # automatic whitespace cleanup on save
    {
      event = [ "BufWritePre" ];
      pattern = [ "*" ];
      command = ":%s/\\s\\+$//e";
      desc = "Remove trailing whitespaces";
    }
  ];
}
