-- Session management for kitty integration
-- Works with ~/Lab_notebook/terminal/kitty-session-manager/

return {
  -- Override LazyVim's persistence.nvim config to use our session file name
  {
    "folke/persistence.nvim",
    opts = {
      -- Save session to .nvim-session.vim in current directory
      -- This matches what kitty-session-manager expects
      dir = vim.fn.getcwd(),
      options = { "buffers", "curdir", "tabpages", "winsize" },
    },
    init = function()
      -- Auto-restore .nvim-session.vim if it exists when nvim starts with no args
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          local session_file = vim.fn.getcwd() .. "/.nvim-session.vim"
          -- Only auto-restore if:
          -- 1. No files were passed as arguments
          -- 2. Session file exists
          -- 3. We're not in a git commit/rebase
          if vim.fn.argc() == 0
              and vim.fn.filereadable(session_file) == 1
              and vim.fn.getcwd() ~= vim.fn.expand("~")
              and not vim.g.started_with_stdin then
            -- Defer to let everything initialize
            vim.defer_fn(function()
              vim.cmd("source " .. vim.fn.fnameescape(session_file))
              vim.notify("Restored session from .nvim-session.vim", vim.log.levels.INFO)
            end, 100)
          end
        end,
        nested = true,
      })

      -- Auto-save session on exit if we have multiple buffers/windows
      vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
          local session_file = vim.fn.getcwd() .. "/.nvim-session.vim"
          -- Only save if we have meaningful state
          local buf_count = #vim.fn.getbufinfo({ buflisted = 1 })
          if buf_count > 1 or vim.fn.winnr("$") > 1 then
            vim.cmd("mksession! " .. vim.fn.fnameescape(session_file))
          end
        end,
      })
    end,
  },
}
