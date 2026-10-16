{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  programs.neovim =
  let
    toLua = str: "lua << EOF\n${str}\nEOF\n";
    toLuaFile = file: "lua << EOF\n${builtins.readFile file}\nEOF\n";
  in
  {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Mantiene los valores que ya usaba la configuración por defecto.
    withRuby = true;
    withPython3 = true;

    extraPackages = with pkgs; [
      intelephense
      lua-language-server
      nixd
      gopls
    ];

    initLua = ''
      ${builtins.readFile ./lua/options.lua}

      -- LSP Servers
      ${builtins.readFile ./lua/lsp/lua_ls.lua}
      ${builtins.readFile ./lua/lsp/intelephense.lua}
      ${builtins.readFile ./lua/lsp/nixd.lua}
      ${builtins.readFile ./lua/lsp/gopls.lua}
    '';

    plugins = with pkgs.vimPlugins; [
      {
        plugin = gruvbox-nvim;
        type = "viml";
        config = "colorscheme gruvbox";
      }

      {
        plugin = nvim-lspconfig;
        config = "";
      }

      luasnip

      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline

      {
        plugin = nvim-cmp;
        type = "viml";
        config = toLuaFile ./lua/plugins/nvim-cmp.lua;
      }

      git-blame-nvim
    ];
  };
}
