-- Iconos (también para oil y snacks), haciéndose pasar por nvim-web-devicons
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Objetos de texto extra: a/i + f (función), c (clase), a (argumento), q (comillas), b (paréntesis)…
local ai = require("mini.ai")
ai.setup({
  n_lines = 500,
  custom_textobjects = {
    f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
  },
})

-- sa (añadir), sd (borrar), sr (cambiar) rodeado: saiw" rodea la palabra con comillas
require("mini.surround").setup()

-- Cierre automático de paréntesis y comillas
require("mini.pairs").setup()

require("mini.statusline").setup()
