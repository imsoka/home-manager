-- Atajos generales. Los de cada plugin están en su fichero de lua/plugins.
-- Neovim 0.12 ya trae para LSP: K (hover), grn (renombrar), gra (acción), grr (referencias),
-- gri (implementación), grt (tipo), gO (símbolos), [d / ]d (diagnósticos), <C-w>d (diagnóstico flotante).
local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Quitar resaltado de búsqueda" })

-- Ventanas
map("n", "<C-h>", "<C-w>h", { desc = "Ventana izquierda" })
map("n", "<C-j>", "<C-w>j", { desc = "Ventana abajo" })
map("n", "<C-k>", "<C-w>k", { desc = "Ventana arriba" })
map("n", "<C-l>", "<C-w>l", { desc = "Ventana derecha" })

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Buffer anterior" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Buffer siguiente" })

-- Mover líneas seleccionadas
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Bajar selección", silent = true })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Subir selección", silent = true })

-- Mantener la selección al indentar
map("v", "<", "<gv")
map("v", ">", ">gv")

map("n", "<leader>w", "<cmd>write<cr>", { desc = "Guardar" })
map("n", "<leader>q", "<cmd>quitall<cr>", { desc = "Salir" })
map("n", "<leader>xq", "<cmd>copen<cr>", { desc = "Quickfix" })

-- Salir del modo terminal con doble Esc
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Salir del modo terminal" })
