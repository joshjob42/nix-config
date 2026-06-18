-- nvim-surround for surrounding text with delimiters
-- Works with tree-sitter for smart selections

return {
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
        -- Custom surrounds for JL
        surrounds = {
          -- Quote form: 'expr
          ["'"] = {
            add = { "'", "" },
            find = "'[^%s%(%)%[%]{}]+",
            delete = "^(')().-()()'?$",
          },
          -- Quasiquote: `expr
          ["`"] = {
            add = { "`", "" },
            find = "`[^%s%(%)%[%]{}]+",
            delete = "^(`)().-()()`?$",
          },
          -- Unquote: ,expr
          [","] = {
            add = { ",", "" },
            find = ",[^%s%(%)%[%]{}@]+",
            delete = "^(,)().-()(,)?$",
          },
          -- List: (expr)
          ["("] = {
            add = { "(", ")" },
          },
          [")"] = {
            add = { "(", ")" },
          },
          -- Vector: [expr]
          ["["] = {
            add = { "[", "]" },
          },
          ["]"] = {
            add = { "[", "]" },
          },
          -- Type params: {expr}
          ["{"] = {
            add = { "{", "}" },
          },
          ["}"] = {
            add = { "{", "}" },
          },
          -- Tuple: (, expr)
          ["t"] = {
            add = { "(, ", ")" },
            find = "%(%,[^%)]*%)",
            delete = "^(%(, ?)().-()(%)$",
          },
          -- Named tuple: (; key val)
          ["n"] = {
            add = { "(; ", ")" },
            find = "%(;[^%)]*%)",
            delete = "^(%(; ?)().-()(%)$",
          },
        },
        -- Use tree-sitter for finding surrounding pairs
        move_cursor = false,
      })
    end,
  },
}
