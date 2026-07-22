{ ... }:
{
  flake.modules.homeManager.zathura =
    { lib, ... }:
    let
      zathuraDesktop = "org.pwmt.zathura.desktop";
      # Document formats zathura-with-plugins can render. Deliberately excludes the
      # generic container types the comic-book plugin also claims (application/zip,
      # x-rar, x-7z-compressed, x-tar, inode/directory) — making a document viewer
      # the default for archives and directories would hijack the archive/file managers.
      documentMimeTypes = [
        "application/pdf"
        "application/oxps"
        "application/epub+zip"
        "application/x-fictionbook"
        "application/postscript"
        "application/eps"
        "application/x-eps"
        "image/eps"
        "image/x-eps"
        "image/vnd.djvu"
        "image/vnd.djvu+multipage"
        "application/x-cbr"
        "application/x-cbz"
        "application/x-cb7"
        "application/x-cbt"
      ];
    in
    {
      programs.zathura.enable = true;

      # Make zathura the default handler for every document format it can open.
      # Enabling this writes ~/.config/mimeapps.list read-only into the store — see
      # the claude module, which declares its own handler for the same reason.
      xdg.mimeApps.enable = true;
      xdg.mimeApps.defaultApplications = lib.genAttrs documentMimeTypes (_: zathuraDesktop);
    };
}
