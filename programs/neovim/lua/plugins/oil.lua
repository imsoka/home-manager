-- oil: el directorio se edita como un buffer y los cambios se aplican con :w
require("oil").setup({
  default_file_explorer = true,
  view_options = { show_hidden = true },
  skip_confirm_for_simple_edits = true,
  keymaps = {
    ["q"] = "actions.close",
  },
})

vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Abrir directorio actual (oil)" })
