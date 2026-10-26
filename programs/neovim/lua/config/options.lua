local opt = vim.opt

-- Numeración
opt.number = true
opt.relativenumber = true
opt.cursorline = true

-- Ancho de línea: guía a 80 y límite a 120
opt.textwidth = 120
opt.colorcolumn = "-40,+0"
opt.wrap = false

-- Columna de signos fija para que el texto no salte al aparecer diagnósticos o cambios de git
opt.signcolumn = "yes"

-- Tabulación por defecto (.editorconfig de cada proyecto la sobrescribe)
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Sin swap, con historial de deshacer persistente
opt.swapfile = false
opt.undofile = true

-- Búsqueda
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

-- Comportamiento general
opt.clipboard = "unnamedplus"
opt.mouse = "a"
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.confirm = true
opt.updatetime = 250
opt.timeoutlen = 300
opt.winborder = "rounded"
opt.showmode = false
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Plegado con treesitter, abierto por defecto
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldlevel = 99

-- Diagnósticos
vim.diagnostic.config({
  update_in_insert = true,
  severity_sort = true,
  virtual_text = { spacing = 2, source = "if_many" },
  float = { source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "",
      [vim.diagnostic.severity.WARN] = "",
      [vim.diagnostic.severity.INFO] = "",
      [vim.diagnostic.severity.HINT] = "",
    },
  },
})

-- Tipos de fichero que Neovim no reconoce solo
vim.filetype.add({
  -- Drupal
  extension = {
    module = "php",
    install = "php",
    inc = "php",
    theme = "php",
    profile = "php",
    engine = "php",
  },
  pattern = {
    ["docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
    ["compose.*%.ya?ml"] = "yaml.docker-compose",
  },
})

-- Resalta brevemente lo copiado
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})
