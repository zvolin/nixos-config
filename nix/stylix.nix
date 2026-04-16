{ pkgs, config, ... }:

let
  inputImage = ../home/wallpapers/aurora-night-sky.jpg;
  brightness = "-9";
  contrast = "6";
  c = config.lib.stylix.colors.withHashtag;
in
{
  stylix = {
    enable = true;
    image = pkgs.runCommand "wallpaper.png" { } ''
      ${pkgs.imagemagick}/bin/convert "${inputImage}" -brightness-contrast ${brightness},${contrast} $out
    '';
    polarity = "dark";
    base16Scheme = {
      scheme = "Catppuccin Mocha (Darker)";
      author = "https://github.com/catppuccin/catppuccin";
      base00 = "#111120"; # base - modified
      base01 = "#0e0e1d"; # mantle - modified
      base02 = "#313244"; # surface0
      base03 = "#45475a"; # surface1
      base04 = "#585b70"; # surface2
      base05 = "#cdd6f4"; # text
      base06 = "#f5e0dc"; # rosewater
      base07 = "#b4befe"; # lavender
      base08 = "#f38ba8"; # red
      base09 = "#fab387"; # peach
      base0A = "#f9e2af"; # yellow
      base0B = "#a6e3a1"; # green
      base0C = "#94e2d5"; # teal
      base0D = "#89b4fa"; # blue
      base0E = "#cba6f7"; # mauve
      base0F = "#f2cdcd"; # flamingo
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 15;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.fira-code;
        name = "FiraCode Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };

      sizes = {
        applications = 10;
        terminal = 10;
        desktop = 8;
        popups = 9;
      };
    };

    targets.nixvim.plugin = "base16-nvim";
  };

  programs.nixvim.highlight = {
    # invisible in base16 with transparency
    TelescopePreviewLine.link = "Visual";
    TelescopePreviewMatch.link = "Search";
    # navic hl groups are not set in base16
    NavicIconsFile.link = "Directory";
    NavicIconsModule.link = "@module";
    NavicIconsNamespace.link = "@module";
    NavicIconsPackage.link = "@module";
    NavicIconsClass.link = "Type";
    NavicIconsMethod.link = "@function.method";
    NavicIconsProperty.link = "@property";
    NavicIconsField.link = "@variable.member";
    NavicIconsConstructor.link = "@constructor";
    NavicIconsEnum.link = "Type";
    NavicIconsInterface.link = "Type";
    NavicIconsFunction.link = "Function";
    NavicIconsVariable.link = "@variable";
    NavicIconsConstant.link = "Constant";
    NavicIconsString.link = "String";
    NavicIconsNumber.link = "Number";
    NavicIconsBoolean.link = "Boolean";
    NavicIconsArray.link = "Type";
    NavicIconsObject.link = "Type";
    NavicIconsKey.link = "Identifier";
    NavicIconsNull.link = "Type";
    NavicIconsEnumMember.link = "Constant";
    NavicIconsStruct.link = "Structure";
    NavicIconsEvent.link = "Structure";
    NavicIconsOperator.link = "Operator";
    NavicIconsTypeParameter.link = "Type";
    NavicText.link = "Comment";
    NavicSeparator.link = "Comment";
    # render-markdown: per-level heading colors
    RenderMarkdownH1 = { fg = c.base0D; bold = true; };  # blue
    RenderMarkdownH2 = { fg = c.base0B; bold = true; };  # green
    RenderMarkdownH3 = { fg = c.base0C; bold = true; };  # teal
    RenderMarkdownH4 = { fg = c.base0E; bold = true; };  # mauve
    RenderMarkdownH5 = { fg = c.base0A; bold = true; };  # yellow
    RenderMarkdownH6 = { fg = c.base08; bold = true; };  # red
    # same colors for treesitter (cursor line / insert mode fallback)
    "@markup.heading.1.markdown" = { fg = c.base0D; bold = true; };
    "@markup.heading.2.markdown" = { fg = c.base0B; bold = true; };
    "@markup.heading.3.markdown" = { fg = c.base0C; bold = true; };
    "@markup.heading.4.markdown" = { fg = c.base0E; bold = true; };
    "@markup.heading.5.markdown" = { fg = c.base0A; bold = true; };
    "@markup.heading.6.markdown" = { fg = c.base08; bold = true; };
    # render-markdown: code, bullets, tables
    RenderMarkdownCode = { bg = c.base01; };       # mantle
    RenderMarkdownBullet = { fg = c.base0C; };      # teal
    # same for treesitter (cursor line / insert mode fallback)
    "@markup.list.markdown" = { fg = c.base0C; };            # teal
    "@markup.list.numbered.markdown" = { fg = c.base0C; };   # teal
    RenderMarkdownTableHead = { fg = c.base0D; };   # blue
    RenderMarkdownTableRow = { fg = c.base07; };    # lavender
  };

  # heading Bg and inline code need darken(), so they're computed in Lua
  programs.nixvim.extraConfigLua = ''
    do
      local function darken(hex, pct, base)
        local function to_rgb(h)
          h = h:gsub("#", "")
          return tonumber(h:sub(1,2),16), tonumber(h:sub(3,4),16), tonumber(h:sub(5,6),16)
        end
        local br, bg, bb = to_rgb(base)
        local fr, fg, fb = to_rgb(hex)
        local f = math.floor
        return string.format("#%02x%02x%02x",
          f(br + (fr-br)*pct), f(bg + (fg-bg)*pct), f(bb + (fb-bb)*pct))
      end
      local base = "${c.base00}"
      local headings = {"${c.base0D}","${c.base0B}","${c.base0C}","${c.base0E}","${c.base0A}","${c.base08}"}
      for i, color in ipairs(headings) do
        vim.api.nvim_set_hl(0, "RenderMarkdownH"..i.."Bg", { fg = color, bg = darken(color, 0.03, base) })
      end
      vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = darken("${c.base02}", 0.35, base) })
    end
  '';
}
