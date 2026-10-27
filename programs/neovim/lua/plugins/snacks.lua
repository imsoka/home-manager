-- snacks.nvim: buscador, explorador, terminal, lazygit, notificaciones y guías de indentación
local Snacks = require("snacks")

-- lazygit escribe su tema en stdpath("cache") sin crear el directorio: si falta, falla con E482
vim.fn.mkdir(vim.fn.stdpath("cache"), "p")

Snacks.setup({
  bigfile = { enabled = true },
  quickfile = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  indent = { enabled = true },
  words = { enabled = true },
  picker = { enabled = true },
  lazygit = { enabled = true },
  terminal = { enabled = true },
  -- oil se encarga de abrir directorios; el explorador solo se abre con <leader>e
  explorer = { enabled = true, replace_netrw = false },
  styles = {
    terminal = {
      keys = {
        -- El doble Esc de serie usa stopinsert, que en nvim 0.12 no saca del modo terminal,
        -- y solo da 200 ms entre pulsaciones: aquí 500
        term_normal = {
          "<esc>",
          function(self)
            self.esc_timer = self.esc_timer or vim.uv.new_timer()
            if self.esc_timer:is_active() then
              self.esc_timer:stop()
              return "<C-\\><C-n>"
            end
            self.esc_timer:start(500, 0, function() end)
            return "<esc>"
          end,
          mode = "t",
          expr = true,
          desc = "Doble Esc: modo normal",
        },
      },
    },
  },
})

local map = vim.keymap.set
local picker = Snacks.picker

-- Buscar
map("n", "<leader><space>", function() picker.smart() end, { desc = "Buscar archivos (inteligente)" })
map("n", "<leader>/", function() picker.grep() end, { desc = "Buscar texto en el proyecto" })
map("n", "<leader>,", function() picker.buffers() end, { desc = "Buffers abiertos" })
map("n", "<leader>ff", function() picker.files() end, { desc = "Archivos" })
map("n", "<leader>fr", function() picker.recent() end, { desc = "Recientes" })
map("n", "<leader>fp", function() picker.projects() end, { desc = "Proyectos" })
map({ "n", "x" }, "<leader>sw", function() picker.grep_word() end, { desc = "Palabra o selección" })
map("n", "<leader>sd", function() picker.diagnostics() end, { desc = "Diagnósticos" })
map("n", "<leader>ss", function() picker.lsp_symbols() end, { desc = "Símbolos del archivo" })
map("n", "<leader>sS", function() picker.lsp_workspace_symbols() end, { desc = "Símbolos del proyecto" })
map("n", "<leader>sh", function() picker.help() end, { desc = "Ayuda" })
map("n", "<leader>sk", function() picker.keymaps() end, { desc = "Atajos" })
map("n", "<leader>sr", function() picker.resume() end, { desc = "Repetir última búsqueda" })
map("n", "<leader>sn", function() Snacks.notifier.show_history() end, { desc = "Historial de notificaciones" })

-- Navegación LSP con vista previa (el resto, gr*, viene de serie)
map("n", "gd", function() picker.lsp_definitions() end, { desc = "Ir a la definición" })
map("n", "gD", function() picker.lsp_declarations() end, { desc = "Ir a la declaración" })
map("n", "]]", function() Snacks.words.jump(vim.v.count1) end, { desc = "Siguiente referencia" })
map("n", "[[", function() Snacks.words.jump(-vim.v.count1) end, { desc = "Referencia anterior" })

-- Explorador, buffers y terminal
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "Explorador (árbol)" })
map("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Cerrar buffer" })
map("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Cerrar los demás buffers" })
map("n", "<leader>tt", function() Snacks.terminal(nil, { win = { position = "float" } }) end, { desc = "Terminal" })

-- Git
map("n", "<leader>gg", function() Snacks.lazygit() end, { desc = "Lazygit" })
map("n", "<leader>gl", function() Snacks.lazygit.log_file() end, { desc = "Historial del archivo" })
map("n", "<leader>gs", function() picker.git_status() end, { desc = "Archivos cambiados" })
map("n", "<leader>gB", function() Snacks.gitbrowse() end, { desc = "Abrir en el navegador" })
