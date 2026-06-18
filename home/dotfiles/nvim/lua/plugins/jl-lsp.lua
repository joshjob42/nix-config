-- JL Language Server configuration for Neovim
-- Provides diagnostics, hover, and completion for .jll files

local jl_lsp_cmd = "/Users/joshjob42/Lab_notebook/julep/bin/jl-lsp"

-- Configure the JL LSP server
local function setup_jl_lsp()
  local lspconfig = require("lspconfig")
  local configs = require("lspconfig.configs")

  -- Only define if not already defined
  if not configs.jl_lsp then
    configs.jl_lsp = {
      default_config = {
        cmd = { jl_lsp_cmd },
        filetypes = { "jl_lisp" },
        root_dir = function(fname)
          return lspconfig.util.find_git_ancestor(fname) or vim.fn.getcwd()
        end,
        settings = {},
      },
      docs = {
        description = [[
JL Language Server

Language server for JL (Julia Lisp) providing diagnostics, hover, and completion.
]],
      },
    }
  end

  -- Setup the server
  lspconfig.jl_lsp.setup({
    on_attach = function(client, bufnr)
      -- Enable completion triggered by <c-x><c-o>
      vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

      -- Buffer local keymaps
      local opts = { buffer = bufnr, noremap = true, silent = true }
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
  })
end

-- Set up after lspconfig is available
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  once = true,
  callback = function()
    -- Delay to ensure lspconfig is loaded
    vim.defer_fn(function()
      local ok, _ = pcall(require, "lspconfig")
      if ok then
        setup_jl_lsp()
      else
        vim.notify("lspconfig not found, JL LSP not configured", vim.log.levels.WARN)
      end
    end, 100)
  end,
})

return {}
