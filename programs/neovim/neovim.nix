{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # La config Lua vive en ./lua y se enlaza en ~/.config/nvim/lua; init.lua solo la carga.
  xdg.configFile."nvim/lua".source = ./lua;

  programs.neovim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    withRuby = false;
    withPython3 = false;

    # Binarios visibles solo para Neovim: LSPs, formateadores y herramientas de los plugins.
    extraPackages = with pkgs; [
      # LSPs
      lua-language-server
      nixd
      gopls
      go # gopls lo necesita para localizar el módulo y la caché
      intelephense
      vtsls
      vue-language-server
      tailwindcss-language-server
      vscode-langservers-extracted # html, cssls, jsonls, eslint
      emmet-language-server
      astro-language-server
      yaml-language-server
      basedpyright
      ruff
      dockerfile-language-server
      docker-compose-language-service

      # Formateadores (conform.nvim)
      prettierd
      stylua
      nixfmt
      gofumpt

      # Herramientas
      ripgrep
      fd
      lazygit
    ];

    initLua = ''
      require("config")
    '';

    plugins = with pkgs.vimPlugins; [
      gruvbox-nvim

      # LSP y completado
      nvim-lspconfig
      SchemaStore-nvim
      lazydev-nvim
      blink-cmp
      friendly-snippets
      conform-nvim

      # Treesitter (solo las gramáticas que usas)
      (nvim-treesitter.withPlugins (p: with p; [
        php php_only phpdoc blade twig
        javascript typescript tsx jsdoc vue astro
        html css scss json yaml toml xml
        go gomod gosum
        nix lua luadoc python bash
        markdown markdown_inline
        dockerfile sql regex diff
        gitcommit git_rebase gitignore
        kdl make vim vimdoc query
      ]))
      nvim-treesitter-textobjects
      nvim-ts-autotag

      # Interfaz
      snacks-nvim
      oil-nvim
      mini-nvim
      which-key-nvim

      # Git
      gitsigns-nvim

      # Claude Code
      claudecode-nvim
    ];
  };
}
