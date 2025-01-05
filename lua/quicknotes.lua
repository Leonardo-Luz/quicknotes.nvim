local floatwindow = require("floatwindow")

local M = {}

local state = {
  window_config = {
    floating = {
      buf = -1,
      win = -1,
    },
    enter = true,
  },
  path = "",
}

M.quick_note = function()
  local filename = "test"

  state.window_config.floating = floatwindow.create_floating_window(state.window_config)

  vim.cmd(string.format("edit %s/%s.md", state.path, filename))

  vim.keymap.set("n", "<esc><esc>", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end, {
    buffer = state.window_config.floating.buf,
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(state.window_config.floating.win, true)
  end, {
    buffer = state.window_config.floating.buf,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.window_config.floating.buf,
    callback = function()
      vim.cmd(string.format("w %s/%s.md", state.path, filename))
    end,
  })
end

vim.api.nvim_create_user_command("Quicknote", M.quick_note, {})

---@class quicknotes.Setup
---@field path string: String to where the notes will be saved

---setup quicknotes plugin
---@param opts quicknotes.Setup
M.setup = function(opts)
  state.path = opts.path
end

return M
