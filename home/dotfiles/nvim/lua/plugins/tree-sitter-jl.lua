-- Tree-sitter support for JL (Julia Lisp)
-- Uses new nvim-treesitter main branch API

-- Register .jll filetype
vim.filetype.add({ extension = { jll = "jl_lisp" } })

local function register_jl_parser()
  local ok, parsers = pcall(require, "nvim-treesitter.parsers")
  if ok and parsers then
    parsers.jl_lisp = {
      install_info = {
        path = "/Users/joshjob42/Lab_notebook/julep/tree-sitter-julep",
      },
    }
  end
end

-- Register on TSUpdate event
vim.api.nvim_create_autocmd("User", {
  pattern = "TSUpdate",
  callback = register_jl_parser,
})

-- Also register after VeryLazy (for LazyVim)
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = register_jl_parser,
})

return {}
