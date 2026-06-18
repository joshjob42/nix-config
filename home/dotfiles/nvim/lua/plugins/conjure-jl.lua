-- Conjure configuration for JL (Julia Lisp)
-- Registers the JL client and sets up filetype mappings

return {
  {
    "Olical/conjure",
    ft = { "fennel", "scheme", "lisp", "jl_lisp" },  -- Clojure handled by conjure-clojure.lua
    dependencies = {
      "PaterJason/cmp-conjure", -- optional: completion source
    },
    init = function()
      -- Add the JL client path to Lua package path
      local jl_client_path = "/Users/joshjob42/Lab_notebook/julep/nvim/lua/?.lua"
      package.path = package.path .. ";" .. jl_client_path

      -- Register JL filetype with Conjure
      vim.g["conjure#filetype#jl_lisp"] = "conjure.client.jl.stdio"

      -- Configure JL client settings
      vim.g["conjure#client#jl#stdio#command"] =
        "julia --project=/Users/joshjob42/Lab_notebook/julep -e 'using JL; JL.repl()'"
      vim.g["conjure#client#jl#stdio#prompt_pattern"] = "jl> "

      -- Optional: enable tree-sitter for form detection
      vim.g["conjure#extract#tree_sitter#enabled"] = true

      -- Conjure log settings
      vim.g["conjure#log#wrap"] = true
      vim.g["conjure#log#hud#width"] = 0.6
      vim.g["conjure#log#hud#height"] = 0.4
    end,
    config = function()
      -- Additional setup after Conjure loads
      require("conjure.main").main()
    end,
  },
}
