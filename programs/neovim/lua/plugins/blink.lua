require("lazydev").setup({
  library = {
    { path = "${3rd}/luv/library", words = { "vim%.uv" } },
  },
})

require("blink.cmp").setup({
  -- Enter confirma, Tab/S-Tab navegan, C-Space abre el menú, C-e lo cierra
  keymap = { preset = "enter" },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 300 },
    list = { selection = { preselect = true, auto_insert = false } },
  },
  signature = { enabled = true },
  sources = {
    default = { "lazydev", "lsp", "path", "snippets", "buffer" },
    providers = {
      lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
    },
  },
})
