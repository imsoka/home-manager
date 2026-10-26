-- Claude Code integrado: abre `claude` en un panel lateral y le da acceso al buffer,
-- la selección y los diagnósticos. Los cambios que propone aparecen como diff.

-- Cuenta según dónde se lanza nvim: dentro de ~/projects/work la del trabajo (~/.claude-work),
-- en cualquier otro sitio la personal (~/.claude). Tiene que fijarse antes de cargar el plugin,
-- que lee CLAUDE_CONFIG_DIR al arrancar para saber dónde dejar el lock que busca `claude`;
-- el `claude` del panel (y cualquier terminal abierta desde nvim) hereda la misma cuenta.
local work_dir = vim.fs.normalize("~/projects/work")
local cwd = vim.fs.normalize(vim.fn.getcwd())
if cwd == work_dir or vim.startswith(cwd, work_dir .. "/") then
  vim.env.CLAUDE_CONFIG_DIR = vim.fs.normalize("~/.claude-work")
else
  vim.env.CLAUDE_CONFIG_DIR = nil
end

require("claudecode").setup({
  terminal = {
    provider = "snacks",
    split_side = "right",
    split_width_percentage = 0.4,
  },
})

local map = vim.keymap.set
map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Abrir/cerrar Claude" })
map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Ir a Claude" })
map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Retomar una sesión" })
map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continuar la última sesión" })
map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Elegir modelo" })
map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Añadir el buffer actual" })
map("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Enviar selección a Claude" })
map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Aceptar diff" })
map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Rechazar diff" })

-- Desde oil o el explorador, <leader>as añade el archivo bajo el cursor
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "oil", "snacks_picker_list" },
  callback = function(args)
    map("n", "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", { buffer = args.buf, desc = "Añadir archivo a Claude" })
  end,
})
