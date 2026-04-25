{...}: {
  flake.modules.nixos.searxng = {
    services.searx = {
      enable = true;
      settings = {
        use_default_settings.engines.keep_only = [
          "wikipedia"
          "wikidata"
          "github"
          "stackoverflow"
          "arch linux wiki"
          "nixos wiki"
          "currency"
        ];
        server = {
          port = 8384;
          bind_address = "127.0.0.1";
          # Flask signing key — predictable and store-readable, accepted tradeoff
          # for a localhost-only instance on an impermanent root partition
          secret_key = "searxng-local-only";
        };
        search = {
          safe_search = 0;
          autocomplete = "";
          default_lang = "en";
          formats = [
            "html"
            "json"
          ];
        };
      };
    };
  };
}
