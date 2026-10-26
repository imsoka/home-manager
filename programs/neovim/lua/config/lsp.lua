-- Las configuraciones base vienen de nvim-lspconfig; aquí solo se ajusta lo propio.
-- Los binarios los pone Nix (extraPackages en neovim.nix).

-- Vue 3: vue_ls gestiona plantilla y estilos, y vtsls el TypeScript con el plugin de Vue
local vue_ls_path = vim.fs.dirname(vim.fs.dirname(vim.fn.exepath("vue-language-server")))
  .. "/lib/language-tools/packages/language-server"

vim.lsp.config("vtsls", {
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
  settings = {
    vtsls = {
      tsserver = {
        globalPlugins = {
          {
            name = "@vue/typescript-plugin",
            location = vue_ls_path,
            languages = { "vue" },
            configNamespace = "typescript",
          },
        },
      },
    },
  },
})

-- PHP: Drupal usa extensiones propias para ficheros PHP
vim.lsp.config("intelephense", {
  settings = {
    intelephense = {
      files = {
        associations = { "*.php", "*.phtml", "*.module", "*.install", "*.inc", "*.theme", "*.profile", "*.engine" },
        exclude = { "**/.git/**", "**/node_modules/**", "**/storage/**", "**/web/sites/*/files/**" },
      },
    },
  },
})

-- HTML y Emmet también en plantillas Blade, Twig, Vue y Astro
local templates = { "blade", "twig", "vue", "astro" }

vim.lsp.config("html", {
  filetypes = vim.list_extend({ "html" }, templates),
})

vim.lsp.config("emmet_language_server", {
  filetypes = vim.list_extend({ "html", "css", "scss", "javascriptreact", "typescriptreact" }, templates),
})

-- JSON y YAML con los esquemas de SchemaStore (package.json, composer.json, workflows…)
vim.lsp.config("jsonls", {
  settings = {
    json = {
      schemas = require("schemastore").json.schemas(),
      validate = { enable = true },
    },
  },
})

vim.lsp.config("yamlls", {
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = require("schemastore").yaml.schemas(),
    },
  },
})

-- Python: ruff hace lint y formato, basedpyright solo tipos
vim.lsp.config("basedpyright", {
  settings = {
    basedpyright = {
      analysis = { typeCheckingMode = "standard" },
    },
  },
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      gofumpt = true,
      staticcheck = true,
      usePlaceholders = true,
    },
  },
})

vim.lsp.enable({
  "lua_ls",
  "nixd",
  "gopls",
  "intelephense",
  "vtsls",
  "vue_ls",
  "tailwindcss",
  "html",
  "cssls",
  "jsonls",
  "eslint",
  "emmet_language_server",
  "astro",
  "yamlls",
  "basedpyright",
  "ruff",
  "dockerls",
  "docker_compose_language_service",
})

-- Atajos que solo tienen sentido con un LSP conectado
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = args.buf, desc = desc })
    end

    map("<leader>cl", "<cmd>checkhealth vim.lsp<cr>", "Estado del LSP")
    if client and client:supports_method("textDocument/inlayHint") then
      map("<leader>ch", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
      end, "Alternar inlay hints")
    end
  end,
})
