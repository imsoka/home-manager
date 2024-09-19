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

    extraPackages = with pkgs; [
      intelephense
      lua-language-server
    ];

    extraLuaConfig = ''
      ${builtins.readFile ./lua/options.lua}

      -- LSP Servers
      ${builtins.readFile ./lua/lsp/lua_ls.lua}
      ${builtins.readFile ./lua/lsp/intelephense.lua}
    '';

    plugins = with pkgs.vimPlugins; [
      {
        plugin = gruvbox-nvim;
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
        config = toLuaFile ./lua/plugins/nvim-cmp.lua;
      }


    ];
  };
}
