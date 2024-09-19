-- Set space as leader
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Basic config
vim.opt.hidden = true

--Numbering
vim.opt.number = true
vim.opt.relativenumber = true

-- Limit line width
vim.opt.textwidth = 120

-- Columns
vim.opt.signcolumn = "auto:1-3"

-- Relative to textwidth
vim.opt.colorcolumn = "-40,+0"

-- Default tab behavior
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Disable swap file, enable Undo file
vim.opt.swapfile = false
vim.opt.undofile = true

-- Never wrap lines
vim.opt.wrap = false

-- Update LSP while on insert mode
vim.diagnostic.config({
  update_in_insert = true
})

-- Dark background
vim.o.background = "dark"
