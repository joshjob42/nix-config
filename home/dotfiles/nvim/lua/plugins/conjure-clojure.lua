-- Conjure configuration for Clojure
-- Separate from JL config to avoid conflicts

return {
  {
    "Olical/conjure",
    ft = { "clojure" },
    dependencies = {
      "PaterJason/cmp-conjure",
    },
    init = function()
      -- Clojure uses nREPL (not stdio like JL)
      vim.g["conjure#client#clojure#nrepl#connection#auto_repl#enabled"] = true
      vim.g["conjure#client#clojure#nrepl#connection#auto_repl#hidden"] = true
      vim.g["conjure#client#clojure#nrepl#connection#auto_repl#cmd"] = "clj -M:nrepl"

      -- Enable tree-sitter for better form detection
      vim.g["conjure#extract#tree_sitter#enabled"] = true

      -- Log window settings
      vim.g["conjure#log#wrap"] = true
      vim.g["conjure#log#hud#width"] = 0.6
      vim.g["conjure#log#hud#height"] = 0.4
      vim.g["conjure#log#hud#enabled"] = true

      -- Evaluation feedback
      vim.g["conjure#highlight#enabled"] = true
      vim.g["conjure#highlight#timeout"] = 500
    end,
    config = function()
      require("conjure.main").main()
    end,
  },

  -- Clojure tree-sitter grammar
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "clojure" })
    end,
  },
}
