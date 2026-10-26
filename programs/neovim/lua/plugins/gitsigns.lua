require("gitsigns").setup({
  current_line_blame = true,
  current_line_blame_opts = { delay = 500 },
  on_attach = function(buf)
    local gs = require("gitsigns")
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end

    map("n", "]h", function() gs.nav_hunk("next") end, "Siguiente cambio")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Cambio anterior")
    map("n", "<leader>hs", gs.stage_hunk, "Añadir cambio al stage")
    map("n", "<leader>hr", gs.reset_hunk, "Descartar cambio")
    map("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Añadir selección al stage")
    map("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Descartar selección")
    map("n", "<leader>hS", gs.stage_buffer, "Añadir archivo al stage")
    map("n", "<leader>hp", gs.preview_hunk_inline, "Ver cambio")
    map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame de la línea")
    map("n", "<leader>hd", gs.diffthis, "Diff del archivo")
    map({ "o", "x" }, "ih", gs.select_hunk, "Cambio (objeto de texto)")
  end,
})
