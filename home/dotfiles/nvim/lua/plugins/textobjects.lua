-- nvim-treesitter-textobjects configuration
-- Uses new function-based API (nvim-treesitter main branch)

return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = "VeryLazy",
    config = function()
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")
      local repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

      -- Config options (lookahead, set_jumps, etc.)
      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true, include_surrounding_whitespace = false },
        move = { set_jumps = true },
      })

      -- Select text objects
      local select_maps = {
        ["af"] = "@function.outer", ["if"] = "@function.inner",
        ["ac"] = "@class.outer",    ["ic"] = "@class.inner",
        ["aa"] = "@parameter.outer", ["ia"] = "@parameter.inner",
        ["ai"] = "@conditional.outer", ["ii"] = "@conditional.inner",
        ["al"] = "@loop.outer",      ["il"] = "@loop.inner",
        ["ab"] = "@block.outer",     ["ib"] = "@block.inner",
        ["ax"] = "@comment.outer",
        ["am"] = "@call.outer",      ["im"] = "@call.inner",
      }
      for key, query in pairs(select_maps) do
        vim.keymap.set({ "x", "o" }, key, function()
          select.select_textobject(query)
        end)
      end

      -- Move to next/prev text objects
      local next_start = {
        ["]f"] = "@function.outer", ["]c"] = "@class.outer",
        ["]a"] = "@parameter.inner", ["]i"] = "@conditional.outer",
        ["]l"] = "@loop.outer",      ["]x"] = "@comment.outer",
      }
      local next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" }
      local prev_start = {
        ["[f"] = "@function.outer", ["[c"] = "@class.outer",
        ["[a"] = "@parameter.inner", ["[i"] = "@conditional.outer",
        ["[l"] = "@loop.outer",      ["[x"] = "@comment.outer",
      }
      local prev_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" }

      for key, query in pairs(next_start) do
        vim.keymap.set({ "n", "x", "o" }, key, function() move.goto_next_start(query) end)
      end
      for key, query in pairs(next_end) do
        vim.keymap.set({ "n", "x", "o" }, key, function() move.goto_next_end(query) end)
      end
      for key, query in pairs(prev_start) do
        vim.keymap.set({ "n", "x", "o" }, key, function() move.goto_previous_start(query) end)
      end
      for key, query in pairs(prev_end) do
        vim.keymap.set({ "n", "x", "o" }, key, function() move.goto_previous_end(query) end)
      end

      -- Swap
      vim.keymap.set("n", "<leader>sa", function() swap.swap_next("@parameter.inner") end)
      vim.keymap.set("n", "<leader>sf", function() swap.swap_next("@function.outer") end)
      vim.keymap.set("n", "<leader>sA", function() swap.swap_previous("@parameter.inner") end)
      vim.keymap.set("n", "<leader>sF", function() swap.swap_previous("@function.outer") end)

      -- Make movements repeatable with ; and ,
      vim.keymap.set({ "n", "x", "o" }, ";", repeat_move.repeat_last_move_next)
      vim.keymap.set({ "n", "x", "o" }, ",", repeat_move.repeat_last_move_previous)
    end,
  },
}
