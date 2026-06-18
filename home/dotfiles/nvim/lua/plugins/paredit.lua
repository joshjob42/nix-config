-- nvim-paredit with JL (Julia Lisp) support
-- Uses query-based language detection (queries/paredit/forms.scm)

return {
  {
    "julienvincent/nvim-paredit",
    ft = { "clojure", "scheme", "lisp", "fennel", "jl_lisp" },
    config = function()
      local paredit = require("nvim-paredit")

      paredit.setup({
        filetypes = { "clojure", "scheme", "lisp", "fennel", "jl_lisp" },
        keys = {
          -- Navigation
          ["<localleader>@"] = { paredit.api.move_to_parent_form_start, "Jump to parent form start" },
          ["<localleader>#"] = { paredit.api.move_to_parent_form_end, "Jump to parent form end" },

          -- Slurp/Barf
          [">)"] = { paredit.api.slurp_forwards, "Slurp forward" },
          [">("] = { paredit.api.barf_backwards, "Barf backward" },
          ["<)"] = { paredit.api.barf_forwards, "Barf forward" },
          ["<("] = { paredit.api.slurp_backwards, "Slurp backward" },

          -- Raise/Splice
          ["<localleader>r"] = { paredit.api.raise_element, "Raise element" },
          ["<localleader>R"] = { paredit.api.raise_form, "Raise form" },
          ["<localleader>s"] = { paredit.api.splice_form, "Splice form" },

          -- Wrap
          ["<localleader>w("] = {
            function() paredit.api.wrap_element_under_cursor("(", ")") end,
            "Wrap element in ()",
          },
          ["<localleader>w)"] = {
            function() paredit.api.wrap_element_under_cursor("(", ")") end,
            "Wrap element in ()",
          },
          ["<localleader>w["] = {
            function() paredit.api.wrap_element_under_cursor("[", "]") end,
            "Wrap element in []",
          },
          ["<localleader>w]"] = {
            function() paredit.api.wrap_element_under_cursor("[", "]") end,
            "Wrap element in []",
          },
          ["<localleader>w{"] = {
            function() paredit.api.wrap_element_under_cursor("{", "}") end,
            "Wrap element in {}",
          },
          ["<localleader>w}"] = {
            function() paredit.api.wrap_element_under_cursor("{", "}") end,
            "Wrap element in {}",
          },

          -- Drag (move elements)
          ["<localleader>h"] = { paredit.api.drag_element_backwards, "Drag element left" },
          ["<localleader>l"] = { paredit.api.drag_element_forwards, "Drag element right" },
          ["<localleader>H"] = { paredit.api.drag_form_backwards, "Drag form left" },
          ["<localleader>L"] = { paredit.api.drag_form_forwards, "Drag form right" },
        },
      })
    end,
  },
}
