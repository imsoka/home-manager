-- Formato solo bajo demanda (<leader>cf) para no reformatear ficheros legados al guardar.
-- Si no hay formateador para el tipo, usa el del LSP.
local web = { "prettierd", "prettier", stop_after_first = true }

require("conform").setup({
  formatters_by_ft = {
    javascript = web,
    typescript = web,
    javascriptreact = web,
    typescriptreact = web,
    vue = web,
    astro = web,
    html = web,
    css = web,
    scss = web,
    json = web,
    jsonc = web,
    yaml = web,
    markdown = web,
    -- pint solo si el proyecto lo tiene en vendor/bin (Laravel moderno)
    php = { "pint" },
    lua = { "stylua" },
    nix = { "nixfmt" },
    go = { "gofumpt" },
    python = { "ruff_format", "ruff_organize_imports" },
  },
  default_format_opts = { lsp_format = "fallback" },
})

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
  require("conform").format({ async = true })
end, { desc = "Formatear archivo o selección" })
