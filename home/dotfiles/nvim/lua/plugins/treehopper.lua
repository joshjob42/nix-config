-- nvim-treehopper for hopping to tree-sitter nodes
-- Jump to any visible node in the syntax tree

return {
  {
    "mfussenegger/nvim-treehopper",
    keys = {
      {
        "<leader>m",
        function()
          require("tsht").nodes()
        end,
        desc = "Treehopper: hop to node",
        mode = { "n", "x", "o" },
      },
      {
        "<leader>M",
        function()
          require("tsht").move({ side = "start" })
        end,
        desc = "Treehopper: move to node start",
        mode = { "n", "x", "o" },
      },
    },
    config = function()
      -- Optional: customize highlight
      vim.api.nvim_set_hl(0, "TSNodeKey", { fg = "#ff9e64", bold = true })
      vim.api.nvim_set_hl(0, "TSNodeUnmatched", { link = "Comment" })
    end,
  },
}
