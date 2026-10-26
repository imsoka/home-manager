-- Las gramáticas vienen de Nix; aquí solo se activan resaltado e indentación
-- en los buffers cuyo tipo tiene gramática instalada.
vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    if not pcall(vim.treesitter.start, args.buf) then
      return
    end
    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})

require("nvim-ts-autotag").setup({})
