-- Punto de entrada: lo carga el init.lua que genera home-manager.
-- El leader tiene que definirse antes de crear cualquier atajo.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.treesitter")
require("config.lsp")

for _, plugin in ipairs({
  "colorscheme",
  "snacks",
  "blink",
  "conform",
  "oil",
  "mini",
  "gitsigns",
  "which-key",
  "claudecode",
}) do
  require("plugins." .. plugin)
end
