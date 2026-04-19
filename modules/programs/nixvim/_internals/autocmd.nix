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
    {
      event = [ "FileType" ];
      pattern = [ "markdown" "rst" ];
      command = "setlocal wrap linebreak breakindent";
      desc = "Enable word-aware wrapping for prose filetypes";
    }
  ];
}
