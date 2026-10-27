-- Al pulsar <leader> (espacio) y esperar, muestra los atajos disponibles
local wk = require("which-key")

wk.setup({ preset = "helix" })

wk.add({
  { "<leader>a", group = "Claude Code" },
  { "<leader>b", group = "Buffers" },
  { "<leader>c", group = "Código" },
  { "<leader>f", group = "Archivos" },
  { "<leader>g", group = "Git" },
  { "<leader>h", group = "Cambios (hunks)" },
  { "<leader>s", group = "Buscar" },
  { "<leader>x", group = "Listas" },
  { "<leader>t", group = "Terminal" },
  { "gr", group = "LSP" },
})
